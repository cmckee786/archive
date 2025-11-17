#!/bin/bash

#v 1.0.1
# Authored by Christian McKee - cmckee786@github.com
# Made for use with podman quadlets, podman >v4.40
# Rootless pihole podman container pipeline

# Allows use of "podman auto-update" to easily update
# pod images based on this label: --label "io.containers.autoupdate=registry"
# Be sure to prune old images periodically

# NOTE: Rootless containers cannot create network devices
# so a tap device is made and NAT is implemented on the host
# via slirp4netns for versions of Podman 4.40 and below, use
# Podman >=v4.41 to benefit from pasta

# Requirements:
# - Podman, ideally passt network package over slirp4netns
# - Redirect all port 80/443 and 53 incoming traffic via firewall
#   - Redirect or front facing reverse proxy is considered more secure
#     than editing sys.ipv4.unprivileged_port_start
# - Implement "service account"
# - Systemd Unit file that utilizes service account
# - Enable service unit and persist service account login

QUADLET_DIR=/home/piholeserviceacc/.config/containers/systemd/

if [[ ! "$EUID" == 0 ]]; then
	printf "Must be run as root\nExiting..."
	exit 1
fi

if ! id piholeserviceacc &>/dev/null; then \
	useradd -m -s /usr/bin/bash piholeserviceacc
	passwd -d piholeserviceacc
	loginctl enable-linger piholeserviceacc
	mkdir -p "$QUADLET_DIR"
	cp ./quadlets/* "$QUADLET_DIR"
	chown -R piholeserviceacc:piholeserviceacc /home/piholeserviceacc
fi

systemctl --user -M piholeserviceacc@ --user daemon-reload
systemctl --user -M piholeserviceacc@ --user start pihole_rootless-pod

#NOTE: From here a decision must be made whether to redirect traffic
# or modify privileged ports after verification of successful start of pod,
# at the very least the Pihole front end should be accessible from
# http(s)://{host_ip}:8080/admin if firewall allows port 8080
#
#NOTE: Possible firewall commands - using UFW for Raspi host
#	- ufw allow from 127.0.0.1 to any port 8080 proto tcp
#		- This redirects the packet, note that this is not forwarding
#	- And further, /etc/ufw/before.rules in the section before `filter`; this is required
#	- *nat
# 		:PREROUTING ACCEPT [0:0]
# 		-A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
# 		COMMIT
# 	- Otherwise unprivileged ports will need to be lowered to at minimum 53
# 		- This could be considered insecure as a privileged user is generally
# 		  expected at ports below 1024
# 		- /etc/sysctl.conf
# 		- net.ipv4.ip_unprivileged_port_start = 53
