#
# VARIABLES
#

variable "aws_region" {
  description = "AWS region to launch servers."
  # This value is being hard-coded to this region. I believe it could be specified at run-time or at some other point. I haven't spent much time with the variables yet to know all the details.
  default     = "us-east-1"
}

variable "aws_amis" {
  default = {
    # This variable is used later for the lookup based on the region value. This is useful if you want to build things in different regions. This pattern was in the already existing examples.
    # Chef Essentials 7.0.0
    us-east-1 = "ami-d5d7ffae"
  }
}

variable "aws_availability_zone" {
    # There were some errors about the subnet being created in an availability
    # zone that did not have access to t1.micros.
    default = "us-east-1a"
}

#
# OUTPUT
#

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
  value = "${aws_route.internet_access.id}"
}

#
# Creation
#

# instances

resource "aws_instance" "webserver" {
  ami           = "${lookup(var.aws_amis, var.aws_region)}"
  instance_type = "t1.micro"
  vpc_security_group_ids = ["${aws_security_group.ssh.id}", "${aws_security_group.web.id}"]
  subnet_id = "${aws_subnet.public.id}"
  availability_zone = "${var.aws_availability_zone}"
  tags {
    Name = "webserver"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum -y install nginx && sudo service nginx start",
      "sudo yum -y install mysql"
    ]

    connection {
      user = "chef"
      password = "Cod3Can!"
    }
  }
}


resource "aws_instance" "database" {
  ami           = "${lookup(var.aws_amis, var.aws_region)}"
  instance_type = "t1.micro"
  vpc_security_group_ids = ["${aws_security_group.ssh.id}", "${aws_security_group.mysql.id}"]
  subnet_id = "${aws_subnet.private.id}"
  availability_zone = "${var.aws_availability_zone}"
  tags {
    Name = "database"
  }

  # The command to grant the remote access these hard coded CIDR range.
  # I would need to change it to use the defined subnet range but convert to
  # this format: 10.0.1.%
  provisioner "remote-exec" {
    inline = [
      "sudo yum -y install mysql-server && sudo service mysqld start",
      "mysql -u root -e 'GRANT ALL ON *.* TO \"root\"@\"10.0.1.%\"'"
    ]

    connection {
      user = "chef"
      password = "Cod3Can!"
    }
  }
}

resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "default" {
  vpc_id = "${aws_vpc.default.id}"
}

resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.default.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.default.id}"
}

resource "aws_subnet" "public" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "${var.aws_availability_zone}"
}

resource "aws_subnet" "private" {
  vpc_id                  = "${aws_vpc.default.id}"
  cidr_block              = "10.0.100.0/24"
  # Ideally this would be a private ip address but I cannot install
  # software on it and configure it.
  # To fix that
  map_public_ip_on_launch = true
  availability_zone = "${var.aws_availability_zone}"
}

resource "aws_security_group" "ssh" {
  name        = "learn_chef_ssh"
  description = "Used in a terraform exercise"
  vpc_id      = "${aws_vpc.default.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web" {
  name        = "learn_chef_web"
  description = "Used in a terraform exercise"
  vpc_id      = "${aws_vpc.default.id}"

  # Allow inbound HTTP connection from all
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "mysql" {
  name        = "learn_chef_mysql"
  description = "Used in a terraform exercise"
  vpc_id      = "${aws_vpc.default.id}"

  # Allow inbound HTTP connection from all
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.100.0/24"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
