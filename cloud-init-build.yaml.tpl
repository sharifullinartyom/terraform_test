package_update: true

packages:
  - openjdk-17-jdk
  - maven
  - git

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

hostname: ${vm_name}
manage_etc_hosts: true

runcmd:
  - java -version
  - mvn -version
