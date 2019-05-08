
// Find AMI
data "aws_ami" "demo-ami" {
  most_recent = true
  owners = ["self", "099720109477"]

  filter {
    name = "name"
    values = ["*nodejs-rds-demo-*"]
  }
  filter {
    name = "state"
    values = ["available"]
  }
}

// Add DB connection information to template file
data "template_file" "cloud-init" {
  template = "${file("init.yml")}"
  vars = {
    db_host = "${aws_db_instance.mydb.address}"
    db_db = "${aws_db_instance.mydb.name}"
    db_user = "${aws_db_instance.mydb.username}"
    db_pass = "${aws_db_instance.mydb.password}"
  }
}

// Setup fronend nodejs server with cloud init template
resource "aws_instance" "node" {

  ami = "${data.aws_ami.demo-ami.id}"
  instance_type = "t3.small"

  associate_public_ip_address = true
  subnet_id = "${element(aws_subnet.public.*.id, count.index)}"

  key_name = "${var.prefix}"
  vpc_security_group_ids = [
    "${aws_security_group.node.id}"
  ]

  user_data = "${data.template_file.cloud-init.rendered}"
  tags {
    Name = "${var.prefix}-nodejs"
  }
}

// Get Route53 Zone to setup node fronend fqdn
data "aws_route53_zone" "demo-zone" {
  name = "iac.trainings.jambit.de."
}

// Set frontend server fqdn
resource "aws_route53_record" "node" {
  count = "${aws_instance.node.count}"
  zone_id = "${data.aws_route53_zone.demo-zone.zone_id}"
  name = "${var.prefix}-${count.index}.${data.aws_route53_zone.demo-zone.name}"
  type = "A"
  ttl = 300
  records = ["${element(aws_instance.node.*.public_ip, count.index)}"]
}

// Allow SSH and HTTP access to nodejs servers
resource "aws_security_group" "node" {
  vpc_id = "${aws_vpc.vpc.id}"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.prefix}-nodejs"
  }
}

// Generate a random DB password
resource "random_string" "password" {
  length = 16
  special = false
}

// Create a DB subnet group that uses the private subnets
resource "aws_db_subnet_group" "default" {
  name = "${var.prefix}-dbsg"
  subnet_ids = ["${aws_subnet.private.*.id}"]

  tags {
    Name = "${var.prefix} DB subnet group"
  }
}

// Create a DB security group that allows access to mysql port
resource "aws_security_group" "db" {
  vpc_id = "${aws_vpc.vpc.id}"

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.prefix}-db"
  }
}

// Set RDS database instance
resource "aws_db_instance" "mydb" {
  identifier = "${var.prefix}-db"
  allocated_storage = 20
  storage_type = "gp2"
  engine = "mysql"
  engine_version = "5.7"
  instance_class = "db.t2.micro"
  name = "mydb"
  username = "${var.prefix}"
  password = "${random_string.password.result}"
  skip_final_snapshot = true
  port = 3306
  db_subnet_group_name = "${var.prefix}-dbsg"
  vpc_security_group_ids = ["${aws_security_group.db.id}"]
}
