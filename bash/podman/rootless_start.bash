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
# - Enable service unit and persist service account login


#NOTE: Change/remove/add global variables to match your environment

USER=chris # root user is preferred method, sudo used due to raspi configurations
REMOTE_TARGET=10.0.0.182
USER_PRIV_KEY="$HOME"/.ssh/raspi/rpi
REMOTE_PRIV_KEY="$HOME"/.ssh/piholeserviceacc/pihole_stack
REMOTE_KEY="$HOME"/.ssh/piholeserviceacc/pihole_stack.pub

#NOTE: May or may not be a necessary if conditional. My remote host only accepts SSH via keys
#	and I am required to shuffle keys into /tmp/ before I can access piholeserviceacc via key

if [[ ! -d "$HOME"/.ssh/piholeserviceacc/ ]]; then
	mkdir -p "$HOME"/.ssh/piholeserviceacc/
	ssh-keygen -t ed25519 -a 32 -f "$HOME"/.ssh/piholeserviceacc/pihole_stack
	scp -i "${USER_PRIV_KEY}" "${REMOTE_KEY}" "${USER}"@"${REMOTE_TARGET}":/tmp/
fi

#NOTE: Remove -i USER_PRIV_KEY if remote target accessible by password
#	-F /dev/null will ignore any config files

ssh -F /dev/null -i "${USER_PRIV_KEY}" "${USER}"@"${REMOTE_TARGET}" "\
if ! id piholeserviceacc &>/dev/null; then \
	sudo bash -c '
	useradd -m -s /usr/bin/bash piholeserviceacc
	passwd -d piholeserviceacc
	mkdir -p /home/piholeserviceacc/.config/systemd/user/
	mkdir -p /home/piholeserviceacc/.ssh/
	touch /home/piholeserviceacc/.ssh/authorized_keys
	cat /tmp/pihole_stack.pub | tee -a /home/piholeserviceacc/.ssh/authorized_keys
	chmod 700 /home/piholeserviceacc/.ssh
	chmod 600 /home/piholeserviceacc/.ssh/authorized_keys
	chown -R piholeserviceacc:piholeserviceacc /home/piholeserviceacc'
fi"
ssh -F /dev/null -i "${REMOTE_PRIV_KEY}" piholeserviceacc@"${REMOTE_TARGET}" "\
podman pod create \
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
    -v piholedata:/etc/pihole/ \
    docker.io/pihole/pihole:latest

podman pod start pod_pihole_rootless
podman generate systemd --new -nf pod_pihole_rootless
mv *.service /home/piholeserviceacc/.config/systemd/user/
systemctl --user enable pod-pod_pihole_rootless
loginctl enable-linger piholeserviceacc
"

#NOTE: From here a decision must be made whether to redirect traffic
# or modify privileged ports after verification of successful start of pod,
# at the very least the Pihole front end should be accessible from
# http(s)://{host_ip}:8080/admin
#
#WARN: To restart from zero:
# From remote host:
# 	loginctl disable-linger piholeserviceacc
# 	rm -rf /home/piholeserviceacc/
# 	pkill -u piholeserviceacc
#	userdel piholeserviceacc
# From user host and account:
#	rm -rf /home/{USER}/.ssh/piholeserviceacc/
# The script can then rebuild the pod from scratch and create new keys,
# service files and pod
