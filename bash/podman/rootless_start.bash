#!/bin/bash

#v 0.1.1
# Authored by Christian McKee - cmckee786@github.com
# Rootless pihole podman container pipeline

# Allows use of "podman auto-update" to easily update
# pod images based on this label: --label "io.containers.autoupdate=registry"
# Be sure to prune old images periodically

# NOTE: Rootless containers cannot create network devices
# so a tap device is made and NAT is implemented on the host

# Requirements:
# - Redirect all port 80/443 and 53 incoming traffic via firewall
#   - Redirect or front facing reverse proxy is considered more secure
#     than editing sys.ipv4.unprivileged_port_start
# - Implement "service account"
# - Systemd Unit file that utilizes service account
# - Enable service unit


pihole_start() {
podman pod create \
	--infra \
	-p 8080:80 \
	-p 8443:443 \
	-p 10053:53 \
	-p 10053:53/udp \
	pod_pihole_rootless

podman create \
	--name cloudflared-cf \
	--pod pod_pihole_rootless \
	--label "io.containers.autoupdate=registry" \
	-e TUNNEL_MANAGEMENT_DIAGNOSTICS=false \
	docker.io/cloudflare/cloudflared:latest proxy-dns \
		--address 0.0.0.0 \
		--port 5353 \
		--upstream https://1.1.1.1/dns-query \
		--upstream https://1.0.0.1/dns-query

podman create \
	--name cloudflared-goog \
	--pod pod_pihole_rootless \
	--label "io.containers.autoupdate=registry" \
	-e TUNNEL_MANAGEMENT_DIAGNOSTICS=false \
	docker.io/cloudflare/cloudflared:latest proxy-dns \
		--address 0.0.0.0 \
		--port 5353 \
		--upstream https://8.8.8.8/dns-query \
		--upstream https://8.8.4.4/dns-query

podman create \
	--name pihole \
	--pod pod_pihole_rootless \
	--label "io.containers.autoupdate=registry" \
	--cap-add SYS_NICE \
	-e TZ='America/New_york' \
	-e FTLCONF_webserver_api_password='change-me!' \
	-e FTLCONF_dns_upstreams='cloudflared-cf#5353;cloudflared-goog#5353' \
	-v /home/chris/pihole/data/etc:/etc/pihole/ \
	docker.io/pihole/pihole:latest

podman pod start pod_pihole_rootless
}

#TODO:
  # - Test generation of systemd unit
  # - Test implementation of service account
  # - Test for necessary command binaries, install dependencies if absent
init() {
	local service_dir="$HOME"/.config/system/user/

	if [[ $(id piholeserviceacc) ]]; then
		pass
	else
		sudo useradd -s /usr/bin/bash piholeserviceacc
	fi

	pihole_start
	mkdir -p "$service_dir" && cd "$service_dir"
	podman generate systemd --new -nf pod_pihole_rootless
	# sed -i /User=piholeserviceacc/ pod-pod_pihole_rootless
	systemctl --user enable --now pod-pod_pihole_rootless
}

init

