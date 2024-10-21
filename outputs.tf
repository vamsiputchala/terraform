output "app_instance_id" {
  value = aws_instance.app.id
}

output "db_endpoint" {
  value = aws_db_instance.default.endpoint
}
