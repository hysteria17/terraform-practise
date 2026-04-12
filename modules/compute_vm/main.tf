# modules/compute_vm/main.tf

terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

# 1. Создаем группу безопасности специально для этого инстанса
resource "yandex_vpc_security_group" "this" {
  name        = "${var.name}-sg"      # Имя SG будет зависеть от имени ВМ
  description = "Security group for ${var.name}"
  network_id  = var.network_id        # ID сети получаем из переменной

  # Разрешаем входящий SSH
  ingress {
    protocol       = "TCP"
    description    = "SSH"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  # Разрешаем входящий HTTP
  ingress {
    protocol       = "TCP"
    description    = "HTTP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  # Разрешаем весь исходящий трафик
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

# 2. Создаем саму виртуальную машину
resource "yandex_compute_instance" "this" {
  name        = var.name
  platform_id = "standard-v1"
  zone        = var.zone

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = var.image_id
    }
  }

  network_interface {
    subnet_id          = var.subnet_id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.this.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_key}"
    # Cloud-init конфиг для установки софта при старте
    user-data = <<EOF
#cloud-config
package_update: true
packages:
  - python3
EOF
  }
}
