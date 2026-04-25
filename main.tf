# 1. Создаем сервисный аккаунт для бэкенда
resource "yandex_iam_service_account" "sa" {
  name = "tf-state-sa-${random_string.unique_id.result}" # Имя должно быть уникальным

  lifecycle {
    prevent_destroy = true
  }
}

# Генерируем случайный суффикс, чтобы имена не пересекались
resource "random_string" "unique_id" {
  length  = 6
  upper   = false
  special = false

  lifecycle {
    prevent_destroy = true
  }
}

# 2. Выдаем права. Для работы со стейтом достаточно роли storage.editor
# Нам нужно получить ID текущего каталога
data "yandex_client_config" "client" {}

resource "yandex_resourcemanager_folder_iam_member" "sa_editor" {
  folder_id = data.yandex_client_config.client.folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.sa.id}"
  lifecycle {
    prevent_destroy = true
  }
}

# 3. Создаем статические ключи доступа (Static Access Keys)
# Они нужны для взаимодействия по S3 API
resource "yandex_iam_service_account_static_access_key" "sa_static_key" {
  service_account_id = yandex_iam_service_account.sa.id
  description        = "Static key for Terraform Backend"

  lifecycle {
    prevent_destroy = true
  }
}

# 4. Создаем бакет для хранения стейта
resource "yandex_storage_bucket" "state_storage" {
  bucket = "tf-state-bucket-${random_string.unique_id.result}"

  # Используем ключи доступа сервисного аккаунта для создания бакета
  access_key = yandex_iam_service_account_static_access_key.sa_static_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa_static_key.secret_key

  depends_on = [
    yandex_resourcemanager_folder_iam_member.sa_editor
  ]
  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  # Защита от случайного удаления (опционально, но рекомендуется)
  # force_destroy = false
}
# Ищем последний доступный образ Ubuntu 24.04 LTS
data "yandex_compute_image" "ubuntu_latest" {
  family = "ubuntu-2404-lts"
  # В Yandex Cloud указание family автоматически выбирает 
  # самый свежий активный образ (аналог most_recent = true в AWS)
}

# 1. Ищем саму сеть (VPC) по имени
data "yandex_vpc_network" "existing_net" {
  name = "default"
}

# 2. Ищем конкретную подсеть в этой сети
data "yandex_vpc_subnet" "existing_subnet" {
  name = "default-ru-central1-a"
  
  # Опционально: можно уточнить поиск, указав ID сети, найденной шагом выше
  # network_id = data.yandex_vpc_network.existing_net.id
}

# External modules

module "vpc_dev" {
  source  = "terraform-yacloud-modules/vpc/yandex"
  version = "3.6.0"
  # Обязательный параметр модуля
  blank_name = "test"
  # Список названий или идентификаторов зон доступности в регионе.
  azs = ["ru-central1-a", "ru-central1-b"]
  # Передаем список подсетей как список списков строк
  public_subnets = [
    ["10.10.1.0/24"],
    ["10.10.2.0/24"]
  ]
}

module "git_example" {
  # 1. Протокол: git::https
  # 2. URL: github.com/...
  # 3. Ref: ?ref=v3.2.4 (Жесткая фиксация версии!)
  source = "git::https://github.com/hashicorp/terraform-provider-null.git?ref=v3.2.4"
}

resource "yandex_compute_instance" "vm" {
  name = "web-server-01"
  platform_id = "standard-v1"
  zone = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_latest.id
    }
  }

  network_interface {
    subnet_id = data.yandex_vpc_subnet.existing_subnet.id
    nat       = true
  }
  
  scheduling_policy {
    preemptible = true
  }

  # Самая важная часть:
  metadata = {
    user-data = templatefile("${path.module}/cloud-configs/cloud-config.yaml", {
      user_name   = "ubuntu"
      ssh_key     = file("~/.ssh/id_rsa.pub")
      server_name = "My Awesome Web Server"
    })
  }
}

# 4. Null Resource для логирования IP
resource "null_resource" "logger" {
  # Самое важное: triggers
  # Этот ресурс будет пересоздан ТОЛЬКО если изменится ID инстанса
  triggers = {
    instance_id = yandex_compute_instance.vm.id
  }

  # Provisioner выполняется локально
  provisioner "local-exec" {
    command = "echo 'New instance created. ID: ${yandex_compute_instance.vm.id}, IP: ${yandex_compute_instance.vm.network_interface.0.nat_ip_address}' >> ips.txt"
  }
}

output "external_ip" {
  value = yandex_compute_instance.vm.network_interface.0.nat_ip_address
}