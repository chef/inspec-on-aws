#
# Variables
#

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" { default = "us-east-1" }
variable "aws_availability_zone" { default = "a" }

#
# Provider
#

provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region = "${var.aws_region}"
}

#
# Data
#

# This retrieves the latest AMI ID for Ubuntu 16.04.

data "aws_ami" "ubuntu" {
  most_recent = true
  owners = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

#
# Creation
#

# networking

resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

resource "aws_route" "internet_access" {
  route_table_id = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.default.id}"
}

resource "aws_subnet" "public" {
  vpc_id = "${aws_vpc.default.id}"
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "${var.aws_region}${var.aws_availability_zone}"
}

resource "aws_subnet" "private" {
  vpc_id = "${aws_vpc.default.id}"
  cidr_block = "10.0.100.0/24"
  availability_zone = "${var.aws_region}${var.aws_availability_zone}"
}

resource "aws_security_group" "ssh" {
  name = "learn_chef_ssh"
  description = "Used in a terraform exercise"
  vpc_id = "${aws_vpc.default.id}"

  # SSH access from anywhere
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web" {
  name = "learn_chef_web"
  description = "Used in a terraform exercise"
  vpc_id = "${aws_vpc.default.id}"

  # Allow inbound HTTP connection from all
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "mysql" {
  name = "learn_chef_mysql"
  description = "Used in a terraform exercise"
  vpc_id = "${aws_vpc.default.id}"

  # Allow inbound TCP connection for MySql from instances from the public subnet
  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  # Allow inbound TCP connection for MySql from instances from the private subnet
  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = ["10.0.100.0/24"]
  }

  # outbound internet access
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# instances

resource "aws_instance" "webserver" {
  ami = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  availability_zone = "${var.aws_region}${var.aws_availability_zone}"
  vpc_security_group_ids = ["${aws_security_group.ssh.id}", "${aws_security_group.web.id}"]
  subnet_id = "${aws_subnet.public.id}"
  tags {
    Name = "webserver"
  }
}

resource "aws_instance" "database" {
  ami = "${data.aws_ami.ubuntu.id}"
  instance_type = "t2.micro"
  availability_zone = "${var.aws_region}${var.aws_availability_zone}"
  vpc_security_group_ids = ["${aws_security_group.ssh.id}", "${aws_security_group.mysql.id}"]
  subnet_id = "${aws_subnet.private.id}"
  tags {
    Name = "database"
  }
}

#
# Output
#

# AMI ID

output "image_id" {
  value = "${data.aws_ami.ubuntu.id}"
}

# webserver details

output "ec2_instance.webserver.name" {
  value = "${aws_instance.webserver.tags.Name}"
}

output "ec2_instance.webserver" {
  value = "${aws_instance.webserver.id}"
}

output "ec2_instance.webserver.ami" {
  value = "${aws_instance.webserver.ami}"
}

output "ec2_instance.webserver.instance_type" {
  value = "${aws_instance.webserver.instance_type}"
}

output "ec2_instance.webserver.public_ip" {
  value = "${aws_instance.webserver.public_ip}"
}

# database details

output "ec2_instance.database.name" {
  value = "${aws_instance.database.tags.Name}"
}

output "ec2_instance.database" {
  value = "${aws_instance.database.id}"
}

output "ec2_instance.database.ami" {
  value = "${aws_instance.database.ami}"
}

output "ec2_instance.database.instance_type" {
  value = "${aws_instance.database.instance_type}"
}

output "ec2_instance.database.private_ip" {
  value = "${aws_instance.database.private_ip}"
}

# networking details

output "vpc.id" {
  value = "${aws_vpc.default.id}"
}

output "subnet.public.id" {
  value = "${aws_subnet.public.id}"
}

output "subnet.private.id" {
  value = "${aws_subnet.private.id}"
}

output "security_group.web.id" {
  value = "${aws_security_group.web.id}"
}

output "security_group.mysql.id" {
  value = "${aws_security_group.mysql.id}"
}

output "security_group.ssh.id" {
  value = "${aws_security_group.ssh.id}"
}

output "route.internet_access.id" {
  value = "${aws_route.internet_access.route_table_id}"
}
