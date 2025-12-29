# Design Doc and Checklist

LEMP (Linux, Nginx, MySQL, PHP) web server stack doc and checklist for chainguard and rootless containers
migration to 1C/1GB/25GB Linode virtual machine (VM). This migration is intended to codify the current cloud
infrastructure from a 'snowflake' implementation into ansible playbooks,possibly terraform, and ultimately
infrastructure as code (IaC).

### Technologies and Frameworks to be Used

- Rocky 10
- Podman and Chainguard Secure Container images
- Ansible, Terraform
- Cloudflare Domain services and Security infrastructure
- Center for Internet Security (CIS) Benchmarks
- NIST CSF 2.0 and Profiles
- OpenSCAP

### Monitoring and Logging (TBD)

- Linode provided dashboard
- Grafana Alloy
    - Pulled downstream to local SoC/NoC implementation
- `collectd` (?)

### Procedure

#### Phase 1 - Migration Preparation

Inventory and pull necessary configs/assets for chainguard implementation

1. Take inventory of current 'snowflake' implementation
    - configs
    - users
    - Wordpress directory
    - systemd analysis/considerations
    - security implementations

2. Pull configs
    - `scp` or `rsync`
        - Nginx, /etc/nginx/nginx.conf and /etc/nginx/sites-(enabled/available)
        - Wordpress, wp-config.php
        - SSH, /etc/ssh/sshd_config.d/ /etc/ssh/sshd_config

3. Compress and pull snowflake MariaDB database to local storage
    - `mariadb-backup`, `tar cfzv`, `rsync`
        - `mariadb-backup --backup`, `mariadb-backup --prepare`
        - `rsync avzh`, `chown -R mysqluser:mysqluser {db-dir}`

4. Compress and pull Wordpress directory to local storage
    - `tar cfzv`, `rsync`
    - Ensure wordpress is up to date prior to pull

#### Phase 2 - Ansible Playbook Local Deploy/Testing

Intended to be tested and implemented on Rocky 10 virtual machine. May need to consider image/kernel
differences between Rocky provided image/kernel and Linode image/kernel

1. Implement Podman quadlet container configurations
    - Chainguard (distroless?) images
        - Nginx
        - MariaDB
        - Wordpress

2. Create role and tasks
    - Baseline security tasks (CIS/NIST controls/benchmarks)
        - `oscap` (?)
    - Firewall tasks
        - `firewalld`, zones, services
    - Package/Dependency tasks
        - `podman`, `python`, `ssh`
    - Create user tasks
        - /etc/subuid, /etc/subgid (100000:65536)
    - Drop in Quadlets and create Podman volumes tasks
        - implement necessary /.config/containers/systemd user directories
    - Pull in Wordpress assets/config tasks
        - `podman volume import {wordpress.tar.gz}`
    - Pull in Nginx config and domain certificate tasks

3. Secrets implementation
    - `ansible vault`
        - ideally secrets only exist in memory briefly, never stored anywhere on remote host
    - passwords, api tokens

4. Testing runs via Ansible
5. Terraform testing

#### Phase 3 - Deploy to Linode

Stage into production

1. Security Baselines
2. Podman and Quadlets
3. Production
