output "webserver" {
  value = aws_instance.webserver.public_ip
}
output "Appserver" {
  value = aws_instance.Appserver.private_ip
}
output "dbserver" {
  value = aws_instance.dbserver.private_ip
}
