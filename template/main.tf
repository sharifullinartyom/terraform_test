data "yandex_compute_image" "os" {
  family = var.image_family
}

resource "yandex_vpc_network" "net" {
  name = "lab-network"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "lab-subnet"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["10.0.1.0/24"]
}

resource "yandex_vpc_security_group" "sg" {
  name       = "ssh-access"
  network_id = yandex_vpc_network.net.id

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  egress {
    protocol       = "ANY"
    description    = "all out"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance" "vm" {
  for_each    = var.vm_params
  name        = each.key
  platform_id = "standard-v3"

  resources {
    cores  = each.value.cores
    memory = each.value.memory
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.os.image_id
      size     = each.value.disk_gb
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.sg.id]
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  }
}

# Build java project

variable "repo_url" {
  type    = string
  default = "https://github.com/sharifullinartyom/terraform_test.git"
}

variable "private_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519"
}

resource "terraform_data" "build" {
  triggers_replace = {
    build_number = timestamp()
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(var.private_key_path)
    host        = yandex_compute_instance.vm["builder"].network_interface[0].nat_ip_address
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install -y git maven openjdk-17-jdk",
      "mvn -version",
      "rm -rf ~/project",
      "git clone ${var.repo_url} ~/project",
      "cd ~/project/app",
      "mvn clean package",
      "ls -la target/",
    ]
  }
}

output "vm_addresses" {
  value = { for name, vm in yandex_compute_instance.vm :
    name => {
      external = vm.network_interface[0].nat_ip_address
      internal = vm.network_interface[0].ip_address
    }
  }
}
