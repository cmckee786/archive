# Rootless Podman Pihole Role

v 1.2.0  
Authored by Christian McKee - cmckee786@github.com  

Implements a rootless Podman Pihole container and upstream Adguard DNS proxy containers with a rootless service account to achieve DNS over HTTPS (DoH).
Allows for Pihole service account to run podman auto-update from shell to easily update container images via registry labels.

Requires Podman >=4.4, firewalld  

## Tested On

Operating System: Rocky Linux 9.7 (Blue Onyx)  
CPE OS Name: cpe:/o:rocky:rocky:9::baseos  
Kernel: Linux 6.1.31-v8.1.el9.altarch  
Instruction Set: ARMv8-A  
Architecture: arm64  
SELinux: Disabled  


Example `ansible-playbook` command:

`ansible-playbook -i roles/pihole/files/hosts.ini playbook.yml --fork 25 -K --ask-vault-pass`
