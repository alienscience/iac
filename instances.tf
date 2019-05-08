
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

// Setup load balancer
resource "aws_elb" "node-balancer" {
  name = "${var.prefix}-elb"

  listener {
    instance_port = 8080
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "HTTP:8080/"
    interval = 30
  }

  instances = ["${aws_instance.node.*.id}"]

  subnets = ["${aws_subnet.public.*.id}"]

  security_groups = [
    "${aws_security_group.elb.id}"
  ]

  tags = {
    Name = "${var.prefix}-elb"
  }
}

// Setup frontend nodejs server with cloud init template
resource "aws_instance" "node" {

  count = 2
  ami = "${data.aws_ami.demo-ami.id}"
  instance_type = "t3.small"

  subnet_id = "${element(aws_subnet.private.*.id, count.index)}"

  key_name = "${var.prefix}"
  vpc_security_group_ids = [
    "${aws_security_group.node.id}"
  ]

  user_data = "${data.template_file.cloud-init.rendered}"
  tags {
    Name = "${var.prefix}-nodejs"
  }
}

// Get Route53 Zone
data "aws_route53_zone" "demo-zone" {
  name = "iac.trainings.jambit.de."
}

// Set elb server fqdn
resource "aws_route53_record" "node" {
  zone_id = "${data.aws_route53_zone.demo-zone.zone_id}"
  name = "${var.prefix}.${data.aws_route53_zone.demo-zone.name}"
  type = "A"

  alias {
    name = "${aws_elb.node-balancer.dns_name}"
    zone_id = "${aws_elb.node-balancer.zone_id}"
    evaluate_target_health = false
  }
}

// Allow HTTP access to load balancer
resource "aws_security_group" "elb" {
  vpc_id = "${aws_vpc.vpc.id}"

  ingress {
    from_port = 80
    to_port = 80
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
    Name = "${var.prefix}-elb"
  }
}

// Allow HTTP access to nodejs servers
resource "aws_security_group" "node" {
  vpc_id = "${aws_vpc.vpc.id}"

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    security_groups = ["${aws_security_group.elb.id}"]
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
    security_groups = ["${aws_security_group.node.id}"]
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
