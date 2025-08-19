### Issue:
creating a proxmox user from proxmox GUI and attempting to edit results in '(500) user not found'
### Cause:
- creating a user from proxmox GUI with PAM authentication requires a proxmox system user
- this user will then need to be created from the command line
### Resolution:
ensure when creating user from proxmox GUI to configure it for pve authentication
