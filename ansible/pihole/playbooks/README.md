# Rootless Podman Pihole

Implements podman pihole container with a rootless service account

Requires Podman >=4.4, firewalld

Tested on:
Raspi 4B  
Operating System: Rocky Linux 9.7 (Blue Onyx)  
CPE OS Name: cpe:/o:rocky:rocky:9::baseos  
Kernel: Linux 6.1.31-v8.1.el9.altarch  
Architecture: arm64  
Instruction Set: ARMv8-A  
SELinux: Disabled  

[Guidance for secrets here](https://docs.ansible.com/projects/ansible/latest/reference_appendices/faq.html#how-do-i-generate-encrypted-passwords-for-the-user-module)

```bash
# To build the rootless containers
ansible-playbook -v -i hosts.ini rootless_install.yml --fork 50 -K --ask-vault-pass

# To remove the rootless container and assets
ansible-playbook -v -i hosts.ini rootless_remove.yml --fork 50 -K
```
