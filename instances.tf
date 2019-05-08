
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

data "template_file" "cloud-init" {
  template = "${file("init.yml")}"
  vars = {
    db_host = "${aws_db_instance.mydb.address}"
    db_db = "${aws_db_instance.mydb.name}"
    db_user = "${aws_db_instance.mydb.username}"
    db_pass = "${aws_db_instance.mydb.password}"
  }
}

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

resource "random_string" "password" {
  length = 16
  special = false
}

resource "aws_db_subnet_group" "default" {
  name = "${var.prefix}-dbsg"
  subnet_ids = ["${aws_subnet.private.*.id}"]

  tags {
    Name = "${var.prefix} DB subnet group"
  }
}

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
