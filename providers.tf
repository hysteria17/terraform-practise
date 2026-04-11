terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
      version = "~> 0.195.0"
    }
  }

  required_version = ">= 1.14.0"
  backend "s3" {
    bucket     = "tf-state-bucket-v7gep3"   # Например: tf-state-bucket-x7z9q1
    region     = "ru-central1"
    key        = "prod/terraform.tfstate"
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }

    # Опции, необходимые для корректной работы с S3-совместимым бэкендом Yandex
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id = true
    skip_metadata_api_check = true
    skip_s3_checksum = true
  }
}
provider "yandex" {
  zone      = "ru-central1-a"
}

# Дополнительный провайдер (Aliased Provider)
# Настроен на другую зону доступности
provider "yandex" {
  alias     = "backup_zone"
#   cloud_id  = "b1g..."
#   folder_id = "b1g..."
  zone      = "ru-central1-d"
}
