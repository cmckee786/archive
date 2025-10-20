#!/bin/bash

#v 1.1.2
# Authored by Christian McKee - cmckee786@github.com
# Rootless pihole podman container pipeline managed by
# lingering service account

# Allows use of "podman auto-update" to easily update
# pod images based on this label: --label "io.containers.autoupdate=registry"
# Be sure to prune old images periodically

# NOTE: Rootless containers cannot create network devices
# so a tap device is made and NAT is implemented on the host
# via slirp4netns

# Requirements:
# - SSH access to remote target with admin privileges
# - Redirect all port 80/443 and 53 incoming traffic via firewall
#   - Redirect or front facing reverse proxy is considered more secure
#     than editing sys.ipv4.unprivileged_port_start
# - Implement "service account"
# - Systemd Unit file that utilizes service account
# - Enable service unit


#NOTE: Change these global variables to match your environment

USER=chris
REMOTE_TARGET=10.0.0.182
USER_PRIV_KEY="$HOME"/.ssh/raspi/rpi
REMOTE_PRIV_KEY="$HOME"/.ssh/piholeserviceacc/pihole_stack
REMOTE_KEY="$HOME"/.ssh/piholeserviceacc/pihole_stack.pub

if [[ ! $(ssh ${USER}@rpi 'id piholeserviceacc') ]]; then
	printf "Implementing pihole service account..."
	ssh -F /dev/null -i "${USER_PRIV_KEY}" "${USER}"@"${REMOTE_TARGET}" "
		sudo bash -c '
		useradd -m -s /usr/bin/bash piholeserviceacc
		passwd -d piholeserviceacc

		mkdir -p /home/piholeserviceacc/.config/systemd/user/
		mkdir -p /home/piholeserviceacc/pihole/data/etc
		mkdir -p /home/piholeserviceacc/.ssh/

		touch /home/piholeserviceacc/.ssh/authorized_keys
		chown -R piholeserviceacc:piholeserviceacc /home/piholeserviceacc
		chmod 700 /home/piholeserviceacc/.ssh
		chmod 600 /home/piholeserviceacc/.ssh/authorized_keys
		'"
fi

if [[ ! -d "$HOME"/.ssh/piholeserviceacc/ ]]; then
	mkdir -p "$HOME"/.ssh/piholeserviceacc/
	ssh-keygen -t ed25519 -a 32 -f "$HOME"/.ssh/piholeserviceacc/pihole_stack
	scp -i "${USER_PRIV_KEY}" "${REMOTE_KEY}" "${USER}"@"${REMOTE_TARGET}":/tmp/
	ssh -i "${USER_PRIV_KEY}" "${USER}"@"${REMOTE_TARGET}" '
		cat /tmp/pihole_stack.pub | sudo tee -a /home/piholeserviceacc/.ssh/authorized_keys
		'
fi

ssh \
	-F /dev/null \
	-i "${REMOTE_PRIV_KEY}" piholeserviceacc@"${REMOTE_TARGET}" \
"podman pod create \
    --infra \
    --network=slirp4netns \
    -p 8080:80 \
    -p 8443:443 \
    -p 10053:53 \
    -p 10053:53/udp \
    pod_pihole_rootless

podman create \
    --name cloudflared-cf \
    --pod pod_pihole_rootless \
    --label 'io.containers.autoupdate=registry' \
    -e TUNNEL_MANAGEMENT_DIAGNOSTICS=false \
    docker.io/cloudflare/cloudflared:latest proxy-dns \
        --address 0.0.0.0 \
        --port 5353 \
        --upstream https://1.1.1.1/dns-query \
        --upstream https://1.0.0.1/dns-query

podman create \
    --name cloudflared-goog \
    --pod pod_pihole_rootless \
    --label 'io.containers.autoupdate=registry' \
    -e TUNNEL_MANAGEMENT_DIAGNOSTICS=false \
    docker.io/cloudflare/cloudflared:latest proxy-dns \
        --address 0.0.0.0 \
        --port 5353 \
        --upstream https://8.8.8.8/dns-query \
        --upstream https://8.8.4.4/dns-query

podman create \
    --name pihole \
    --pod pod_pihole_rootless \
    --label 'io.containers.autoupdate=registry' \
    --cap-add SYS_NICE \
    -e TZ='America/New_York' \
    -e FTLCONF_webserver_api_password='change-me!' \
    -e FTLCONF_dns_upstreams='cloudflared-cf#5353;cloudflared-goog#5353' \
    -v /home/piholeserviceacc/pihole/data/etc:/etc/pihole/ \
    docker.io/pihole/pihole:latest

podman pod start pod_pihole_rootless
podman generate systemd --new -nf pod_pihole_rootless
mv *.service /home/piholeserviceacc/.config/systemd/user/
systemctl --user enable pod-pod_pihole_rootless
loginctl enable-linger piholeserviceacc
"

#NOTE: From here a decision should be made whether to redirect traffic
# or modify privileged ports after verification of successful start of pod
#
#WARN: To restart from zero:
# From remote host:
# 	podman pod rm -f pod_pihole_rootless
# 	rm /home/piholeserviceacc/.config/systemd/user/*.service
# 	sudo rm -rf /home/piholeserviceacc/
#	sudo userdel piholeserviceacc
# From user host and account:
#	rm -rf /home/{USER}/.ssh/piholeserviceacc/
# The script will then rebuild from scratch and create new keys, service files
# and pod
