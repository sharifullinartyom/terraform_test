locals {
  cloud_config = templatefile("${path.module}/cloud-init.yaml.tpl", {
    ssh_public_key = file(var.ssh_public_key_path)
    vm_name        = var.vm_name
    user_password  = var.user_password
  })
  tomcat_config = templatefile("${path.module}/cloud-init-tomcat.yaml.tpl", {
     user_password  = var.user_password
    ssh_public_key = file(var.ssh_public_key_path)
  })

}

# =============================================================================
# Data sources
# =============================================================================

data "cloudru_evolution_compute_image_collection" "ubuntu" {
  project_id = var.project_id
  page_size  = 100
}

# =============================================================================
# VPC
# =============================================================================

resource "cloudru_evolution_vpc_vpc" "main" {
  project_id  = var.project_id

  name = var.vm_name

  description = "VPC для Terraform"
}

# =============================================================================
# Subnet
# =============================================================================

resource "cloudru_evolution_compute_subnet" "example" {
  project_id  = var.project_id

  name        = "tf-evo-subnet"

  description = "Подсеть для ВМ"

  zone = {
    name = var.zone
  }

  subnet_address = var.subnet_address

  routed_network = true

  default        = true

  vpc_id         = cloudru_evolution_vpc_vpc.main.id

  dns_servers = {
    value = ["8.8.4.4", "8.8.8.8"]
  }
}

# =============================================================================
# Security group
# =============================================================================

resource "cloudru_evolution_compute_security_group" "example" {
  project_id  = var.project_id

  name        = "tf-evo-sg"

  description = "Группа безопасности для ВМ"

  zone = {
    name = var.zone
  }
}

# =============================================================================
# Security group rules
# =============================================================================

# SSH (22)
resource "cloudru_evolution_compute_security_group_rule" "ingress_ssh" {
  security_group_id = cloudru_evolution_compute_security_group.example.id
  description       = "SSH доступ с моего IP"
  direction         = "TRAFFIC_DIRECTION_INGRESS"
  ether_type        = "ETHER_TYPE_IPV4"
  ip_protocol       = "IP_PROTOCOL_TCP"
  port_range        = "22:22"
  remote_ip_prefix  = var.my_ip_cidr
}

# HTTPS (443) — access from everywhere
resource "cloudru_evolution_compute_security_group_rule" "ingress_https" {
  security_group_id = cloudru_evolution_compute_security_group.example.id
  description       = "HTTPS доступ отовсюду"
  direction         = "TRAFFIC_DIRECTION_INGRESS"
  ether_type        = "ETHER_TYPE_IPV4"
  ip_protocol       = "IP_PROTOCOL_TCP"
  port_range        = "443:443"
  remote_ip_prefix  = "0.0.0.0/0"
}

# Egress TCP
resource "cloudru_evolution_compute_security_group_rule" "egress_tcp" {
  security_group_id = cloudru_evolution_compute_security_group.example.id
  description       = "Разрешить весь исходящий TCP"
  direction         = "TRAFFIC_DIRECTION_EGRESS"
  ether_type        = "ETHER_TYPE_IPV4"
  ip_protocol       = "IP_PROTOCOL_TCP"
  port_range        = "1:65535"
  remote_ip_prefix  = "0.0.0.0/0"
}

# Egress UDP
resource "cloudru_evolution_compute_security_group_rule" "egress_udp" {
  security_group_id = cloudru_evolution_compute_security_group.example.id
  direction         = "TRAFFIC_DIRECTION_EGRESS"
  ether_type        = "ETHER_TYPE_IPV4"
  ip_protocol       = "IP_PROTOCOL_UDP"
  port_range        = "1:65535"
  description       = "Разрешить весь исходящий UDP"
  remote_ip_prefix  = "0.0.0.0/0"
}

# =============================================================================
# Boot disk
# =============================================================================

resource "cloudru_evolution_compute_disk" "example" {
  project_id  = var.project_id

  name        = "tf-evo-disk"

  description = "Загрузочный диск для ВМ"

  size        = var.disk_size

  zone = {
    name = var.zone
  }

  disk_type = {
    name = var.disk_type
  }

  image  = {
    id = [for img in data.cloudru_evolution_compute_image_collection.ubuntu.images : img.id if img.name == "ubuntu-22.04"][0]
  }

  bootable  = true

  encrypted = false

  readonly  = false

  shared    = false
}

# =============================================================================
# External IP
# =============================================================================

resource "cloudru_evolution_compute_external_ip" "example" {
  project_id  = var.project_id

  name        = "tf-evo-public-ip"

  description = "Публичный IP-адрес для ВМ"

  zone = {
    name = var.zone
  }
}

# =============================================================================
# Network interface
# =============================================================================

resource "cloudru_evolution_compute_interface" "example" {
  project_id  = var.project_id

  name        = "tf-evo-interface"

  description = "Сетевой интерфейс для ВМ"

  subnet = {
    id = cloudru_evolution_compute_subnet.example.id
  }

  zone = {
    name = var.zone
  }

  interface_security_enabled = true

  security_groups = [{
    id = cloudru_evolution_compute_security_group.example.id
  }]

  attach_external_ip = {
    id = cloudru_evolution_compute_external_ip.example.id
  }

  type = "INTERFACE_TYPE_REGULAR"
}

# =============================================================================
# Virtual machine
# =============================================================================

resource "cloudru_evolution_compute_vm" "example" {
  project_id = var.project_id

  name = var.vm_name

  description = "ВМ, созданная через Terraform"

  zone = {
    name = var.zone
  }

  flavor = {
    name = var.flavor
  }

  disks = [{
    id = cloudru_evolution_compute_disk.example.id
  }]

  network_interfaces = [{
    id = cloudru_evolution_compute_interface.example.id
  }]

  image_metadata = {
    "name" = {
      string_value = "user1"
    }
    "hostname" = {
      string_value = var.vm_name
    }
    "linux_password" = {
      string_value = var.user_password
    }
    "public_key" = {
      string_value = file(var.ssh_public_key_path)
    }
  }
  cloud_init_userdata = base64encode(local.cloud_config)
}

# =============================================================================
# Output of values
# =============================================================================

output "vm_id" {
  description = "Идентификатор виртуальной машины"
  value       = cloudru_evolution_compute_vm.example.id
}

output "vm_name" {
  description = "Название виртуальной машины"
  value       = cloudru_evolution_compute_vm.example.name
}

output "vm_internal_ip" {
  description = "Внутренний IP-адрес"
  value       = cloudru_evolution_compute_interface.example.ip_address
}

output "external_ip" {
  description = "Публичный IP-адрес"
  value       = cloudru_evolution_compute_external_ip.example.ip_address
}

# =============================================================================
# Tomcat VM: security rule (8080)
# =============================================================================

resource "cloudru_evolution_compute_security_group_rule" "ingress_tomcat" {
  security_group_id = cloudru_evolution_compute_security_group.example.id
  description       = "Tomcat доступ с моего IP"
  direction         = "TRAFFIC_DIRECTION_INGRESS"
  ether_type        = "ETHER_TYPE_IPV4"
  ip_protocol       = "IP_PROTOCOL_TCP"
  port_range        = "8080:8080"
  remote_ip_prefix  = var.my_ip_cidr
}

# =============================================================================
# Tomcat VM: external IP
# =============================================================================

resource "cloudru_evolution_compute_external_ip" "tomcat" {
  project_id  = var.project_id
  name        = "tf-evo-tomcat-ip"
  description = "Публичный IP для Tomcat ВМ"
  zone = {
    name = var.zone
  }
}

# =============================================================================
# Tomcat VM: boot disk
# =============================================================================

resource "cloudru_evolution_compute_disk" "tomcat" {
  project_id  = var.project_id
  name        = "tf-evo-tomcat-disk"
  description = "Загрузочный диск для Tomcat ВМ"
  size        = var.disk_size
  zone = {
    name = var.zone
  }
  disk_type = {
    name = var.disk_type
  }
  image = {
    id = [for img in data.cloudru_evolution_compute_image_collection.ubuntu.images : img.id if img.name == "ubuntu-22.04"][0]
  }
  bootable  = true
  encrypted = false
  readonly  = false
  shared    = false
}

# =============================================================================
# Tomcat VM: network interface
# =============================================================================

resource "cloudru_evolution_compute_interface" "tomcat" {
  project_id  = var.project_id
  name        = "tf-evo-tomcat-interface"
  description = "Сетевой интерфейс для Tomcat ВМ"
  subnet = {
    id = cloudru_evolution_compute_subnet.example.id   # та же подсеть
  }
  zone = {
    name = var.zone
  }
  interface_security_enabled = true
  security_groups = [{
    id = cloudru_evolution_compute_security_group.example.id   # та же SG
  }]
  attach_external_ip = {
    id = cloudru_evolution_compute_external_ip.tomcat.id
  }
  type = "INTERFACE_TYPE_REGULAR"
}

# =============================================================================
# Tomcat VM
# =============================================================================

resource "cloudru_evolution_compute_vm" "tomcat" {
  project_id  = var.project_id
  name        = "tf-evo-tomcat"
  description = "ВМ с Tomcat для WAR"
  zone = {
    name = var.zone
  }
  flavor = {
    name = var.flavor
  }
  disks = [{
    id = cloudru_evolution_compute_disk.tomcat.id
  }]
  network_interfaces = [{
    id = cloudru_evolution_compute_interface.tomcat.id
  }]

  cloud_init_userdata = base64encode(local.tomcat_config)
}

# =============================================================================
# Output for Tomcat VM
# =============================================================================

output "tomcat_external_ip" {
  description = "Публичный IP Tomcat ВМ"
  value       = cloudru_evolution_compute_external_ip.tomcat.ip_address
}

output "tomcat_internal_ip" {
  description = "Внутренний IP Tomcat ВМ"
  value       = cloudru_evolution_compute_interface.tomcat.ip_address
}
