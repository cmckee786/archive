Rootless Podman Pihole Role
=========

Implements a rootless Podman Pihole container and upstream Adguard DNS proxy containers with a rootless service account
to achieve DNS over HTTPS (DoH).

Allows for Pihole service account to run `podman auto-update` from shell to easily update container images via registry labels.

Requirements
------------

Podman version capable of utilizing Podman Quadlets (>= v4.4)

Role Variables
--------------

Secrets.yml should be reviewed and encrypted via ansible-vault. This yaml passes the Pihole web frontend password and
service account password via a template and user module respectively.

Dependencies
------------

None

Example Playbook
----------------

    - hosts: all
      gather_facts: true
      become: true

      roles:
        - role: roles/pihole
          # vars:
          #   - pihole_user: user defined service account

License
-------

MIT
