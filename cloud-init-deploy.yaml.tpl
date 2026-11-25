#cloud-config
package_update: true

packages:
  - tomcat9
  - openjdk-17-jdk

users:
  - name: user1
    groups: sudo
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    lock_passwd: false
    ssh_authorized_keys:
      - ${ssh_public_key}

chpasswd:
  expire: false
  list: |
    user1:${user_password}

runcmd:
  - systemctl enable --now tomcat9
  - chown -R tomcat:tomcat /var/lib/tomcat9/webapps
