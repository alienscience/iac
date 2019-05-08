
output "elb-ip" {
  value = "${aws_elb.node-balancer.*.dns_name}"
}

output "db-ip" {
  value = "${aws_db_instance.mydb.*.address}"
}

output "db-password" {
  value = "${aws_db_instance.mydb.password}"
}
