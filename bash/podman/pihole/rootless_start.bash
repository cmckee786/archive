#!/bin/bash

#v 1.1.4
# Authored by Christian McKee - cmckee786@github.com
# Made for use with Raspi's on Debian 12 and podman v4.3.1

# Rootless pihole podman container pipeline managed by
# lingering service account

# Allows use of "podman auto-update" to easily update
# pod images based on this label: --label "io.containers.autoupdate=registry"
# Be sure to prune old images periodically

# NOTE: Rootless containers cannot create network devices
# so a tap device is made and NAT is implemented on the host
# via slirp4netns for versions of Podman 4.40 and below, use
# Podman >=v4.41 to benefit from pasta

# Requirements:
# - Podman, ideally passt network package over slirp4netns
# - SSH access to remote target with admin privileges
# - Redirect all port 80/443 and 53 incoming traffic via firewall
#   - Redirect or front facing reverse proxy is considered more secure
#     than editing sys.ipv4.unprivileged_port_start
# - Implement "service account"
# - Systemd Unit file that utilizes service account
# - Enable service unit and persist service account login

#NOTE: Change/remove/add global variables to match your environment

USER=chris
SERVICE_ACCOUNT=piholeserviceacc
REMOTE_TARGET=10.0.0.182
USER_PRIV_KEY="$HOME"/.ssh/raspi/rpi # keys may not be necessary per environment
REMOTE_PRIV_KEY="$HOME"/.ssh/"${SERVICE_ACCOUNT}"/pihole_stack
REMOTE_KEY="$HOME"/.ssh/"${SERVICE_ACCOUNT}"/pihole_stack.pub

# May be a necessary if conditional. My remote Raspi 4B only accepts SSH via keys
# and I am required to transfer the public key into /tmp/ before I can access
# piholeserviceacc via ssh

# Ran from host
# Create private and public key access for service account
if [[ ! -d "$HOME"/.ssh/"${SERVICE_ACCOUNT}"/ ]]; then
    mkdir -p "$HOME"/.ssh/"${SERVICE_ACCOUNT}"/
    ssh-keygen -t ed25519 -a 32 -f "$HOME"/.ssh/"${SERVICE_ACCOUNT}"/pihole_stack
    scp -i "${USER_PRIV_KEY}" "${REMOTE_KEY}" "${USER}"@"${REMOTE_TARGET}":/tmp/
fi

# Ran on Raspi 4B
# Check for and create service account via ssh
ssh -F /dev/null -i "${USER_PRIV_KEY}" "${USER}"@"${REMOTE_TARGET}" "\
if ! id ${SERVICE_ACCOUNT} &>/dev/null; then \
    sudo -S bash -c '
    useradd -m -s /usr/bin/bash ${SERVICE_ACCOUNT}
    passwd -d ${SERVICE_ACCOUNT}
    loginctl enable-linger ${SERVICE_ACCOUNT}
    mkdir -p /home/${SERVICE_ACCOUNT}/.config/systemd/user/
    mkdir -p /home/${SERVICE_ACCOUNT}/.ssh/
    touch /home/${SERVICE_ACCOUNT}/.ssh/authorized_keys
    cat /tmp/pihole_stack.pub | tee -a /home/${SERVICE_ACCOUNT}/.ssh/authorized_keys
    chmod 700 /home/${SERVICE_ACCOUNT}/.ssh
    chmod 600 /home/${SERVICE_ACCOUNT}/.ssh/authorized_keys
    chown -R ${SERVICE_ACCOUNT}:${SERVICE_ACCOUNT} /home/${SERVICE_ACCOUNT}
    usermod --add-subuids 100000-165535 --add-subgids 100000-165535 ${SERVICE_ACCOUNT}
    podman system migrate
    firewall-cmd --permanent --zone=public --add-forward-port=port=80:proto=tcp:toport=8080
    firewall-cmd --permanent --zone=public --add-forward-port=port=443:proto=tcp:toport=8443
    firewall-cmd --permanent --zone=public --add-forward-port=port=53:proto=tcp:toport=10053
    firewall-cmd --permanent --zone=public --add-forward-port=port=53:proto=udp:toport=10053
    firewall-cmd --reload'
fi"

# It is far simpler to use an ssh connection and login than su or other utilities
ssh -F /dev/null -i "${REMOTE_PRIV_KEY}" "${SERVICE_ACCOUNT}"@"${REMOTE_TARGET}" "\
podman pod create \
    --infra \
    --userns auto \
    --network=pasta \
    -p 8080:80 \
    -p 8443:443 \
    -p 10053:53 \
    -p 10053:53/udp \
    pod_pihole_rootless

podman create \
    --name adguard-cf \
    --pod pod_pihole_rootless \
    --label 'io.containers.autoupdate=registry' \
    docker.io/adguard/dnsproxy:latest \
	-p 5353 \
	-u h3://1.1.1.1/dns-query \
	-u h3://1.0.0.1/dns-query

podman create \
    --name adguard-goog \
    --pod pod_pihole_rootless \
    --label 'io.containers.autoupdate=registry' \
    docker.io/adguard/dnsproxy:latest \
	-p 5353 \
	-u h3://8.8.8.8/dns-query \
	-u h3://8.8.4.4/dns-query

podman create \
    --name pihole \
    --pod pod_pihole_rootless \
    --label 'io.containers.autoupdate=registry' \
    --cap-add SYS_NICE \
    -e TZ='America/New_York' \
    -e FTLCONF_webserver_api_password='change-me!' \
    -e FTLCONF_dns_upstreams='adguard-cf#5353;adguard-goog#5353' \
    -v piholedata:/etc/pihole/ \
    docker.io/pihole/pihole:latest

podman pod start pod_pihole_rootless
podman generate systemd --new -nf pod_pihole_rootless
mv *.service /home/${SERVICE_ACCOUNT}/.config/systemd/user/
systemctl --user enable pod-pod_pihole_rootless
"

#NOTE: To restart from zero:
# - From remote host:
#   - login to service account then:
#       - podman pod rm --force pod_pihole_rootless
#       - exit service account
# 	- loginctl disable-linger piholeserviceacc
# 	- rm -rf /home/piholeserviceacc/
#	- userdel piholeserviceacc
# - If you wish to delete key, from user host and account:
#	- rm -rf /home/{USER}/.ssh/piholeserviceacc/
# The script can then rebuild the pod from scratch and create new keys,
# service files and pod
