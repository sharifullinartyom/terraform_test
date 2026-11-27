resource "yandex_vpc_network" "net" {
  name = "lab-network"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "lab-subnet"
  zone           = var.zone
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

  ingress {
    protocol       = "TCP"
    description    = "Tomcat 8080"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 8080
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

data "yandex_compute_image" "os" {
  family = var.image_family
}

# Build java project

resource "terraform_data" "build" {
  triggers_replace = {
    build_number = timestamp()
  }

  connection {
    type        = "ssh"
    user        = var.ssh_user
    private_key = file(pathexpand(var.private_key_path))
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

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${pathexpand(var.private_key_path)} ${var.ssh_user}@${yandex_compute_instance.vm[\"builder\"].network_interface[0].nat_ip_address}:/home/ubuntu/project/app/target/SimpleTomcatWebApp.war ./SimpleTomcatWebApp.war"
  }
}

# Deploy war with Tomcat9

resource "terraform_data" "deploy" {
  triggers_replace = [terraform_data.build]

  provisioner "file" {
    source      = "./SimpleTomcatWebApp.war"
    destination = "/tmp/SimpleTomcatWebApp.war"

    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(pathexpand(var.private_key_path))
      host        = yandex_compute_instance.vm["deployer"].network_interface[0].nat_ip_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      <<-EOT
        sudo apt update
        sudo apt install -y tomcat9
        sudo systemctl stop tomcat9 || true
        sudo rm -rf /var/lib/tomcat9/webapps/SimpleTomcatWebApp
        sudo cp /tmp/SimpleTomcatWebApp.war /var/lib/tomcat9/webapps/
        sudo chown tomcat9:tomcat9 /var/lib/tomcat9/webapps/SimpleTomcatWebApp.war
        sudo systemctl restart tomcat9
        sleep 15
        echo '=== Проверка приложения: ==='
        curl -s -o /dev/null -w 'HTTP status: %%{http_code}\n' http://localhost:8080/SimpleTomcatWebApp/
      EOT
    ]

    connection {
      type        = "ssh"
      user        = var.ssh_user
      private_key = file(pathexpand(var.private_key_path))
      host        = yandex_compute_instance.vm["deployer"].network_interface[0].nat_ip_address
    }
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
