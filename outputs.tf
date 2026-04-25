# 5. Выводим данные, которые нам понадобятся для настройки бэкенда
output "access_key" {
  value = yandex_iam_service_account_static_access_key.sa_static_key.access_key
}

output "secret_key" {
  value     = yandex_iam_service_account_static_access_key.sa_static_key.secret_key
  sensitive = true # Terraform скроет это значение в консоли по умолчанию
}

output "bucket_name" {
  value = yandex_storage_bucket.state_storage.bucket
}

# Блок output поможет нам проверить, что именно нашёл Terraform
output "current_image_id" {
  value = data.yandex_compute_image.ubuntu_latest.id
}