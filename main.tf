# resource "null_resource" "long_process" {
#   # Этот ресурс будет пересоздаваться каждый раз, если мы изменим триггер
#   triggers = {
#     always_run = "${timestamp()}"
#   }

#   provisioner "local-exec" {
#     command = "sleep 30"
#   }
# }

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

# # Ресурс создается в зоне по умолчанию (ru-central1-a)
# resource "yandex_vpc_network" "default_net" {
#   name = "main-network"
# }

# # Ресурс создается в зоне backup_zone (ru-central1-b)
# resource "yandex_compute_instance" "backup_vm" {
#   provider = yandex.backup_zone # Явное указание провайдера

#   name        = "backup-server"
#   platform_id = "standard-v1"
#   # Остальные параметры...
# }

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

# resource "yandex_compute_instance" "vm_integrated" {
#   name        = "vm-in-existing-net"
#   platform_id = "standard-v1"
#   zone        = "ru-central1-a"

#   resources {
#     cores  = 2
#     memory = 2
#   }

#   boot_disk {
#     initialize_params {
#       # Используем ID образа, найденный в предыдущем шаге (через data)
#       image_id = data.yandex_compute_image.ubuntu_latest.id
#     }
#   }

#   network_interface {
#     # ВМЕСТО ХАРДКОДА: "e9b..."
#     # МЫ ИСПОЛЬЗУЕМ ССЫЛКУ НА DATA SOURCE:
#     subnet_id = data.yandex_vpc_subnet.existing_subnet.id
#     nat       = true
#   }
# }

# 3. Ресурс с использованием логики
resource "yandex_compute_instance" "vm" {
  name        = local.vm_name
  platform_id = "standard-v3"
  
  # Используем locals для меток
  labels = local.common_labels

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_latest.id # Ubuntu 24.04 LTS
    }
  }

  network_interface {
    # Используем default подсеть (убедитесь, что она есть, или создайте yandex_vpc_subnet)
    subnet_id = data.yandex_vpc_subnet.existing_subnet.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }

  # Самое интересное: настройка прерываемости через тернарный оператор
  scheduling_policy {
    preemptible = local.is_preemptible
  }
}

# Создаем 3 одинаковые ВМ с разными именами
resource "yandex_compute_instance" "web_cluster" {
  count = 3  # <--- Магия здесь

  # Используем индекс для уникальности имени
  name = "web-server-${count.index}" 
  
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu_latest.id # Ubuntu 24.04
    }
  }

  network_interface {
    subnet_id = data.yandex_vpc_subnet.existing_subnet.id # <-- Укажите ваш subnet_id
    nat       = true
  }

  # Самое интересное: настройка прерываемости через тернарный оператор
  scheduling_policy {
    preemptible = local.is_preemptible
  }

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_compute_instance" "services" {
  # Итерируемся по карте. Будет создано 3 ресурса.
  for_each = var.virtual_machines

  # Формируем уникальное имя, используя ключ
  name = "service-${each.key}" # service-db, service-app...
  
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    # Берем параметры из значения (each.value)
    cores  = each.value.cores
    memory = each.value.memory
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

  metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

# 2. Создаем ресурс с динамическими блоками
resource "yandex_vpc_security_group" "dynamic_sg" {
  name        = "dynamic-web-sg"
  description = "Security group with dynamic rules"
  network_id  = data.yandex_vpc_network.existing_net.id

  # Генерируем блоки ingress
  dynamic "ingress" {
    for_each = local.allowed_ports
    
    # content - это то, что будет внутри блока ingress { ... }
    content {
      protocol       = "TCP"
      description    = "Rule for port ${ingress.value}"
      port           = ingress.value # Обращаемся к текущему значению итератора
      v4_cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Egress правило (обычно одно, разрешающее всё исходящее)
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}
