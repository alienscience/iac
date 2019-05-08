
output "node-ip" {
  value = "${aws_instance.node.*.public_ip}"
}

output "db-ip" {
  value = "${aws_db_instance.mydb.*.address}"
}

output "db-password" {
  value = "${aws_db_instance.mydb.password}"
}
