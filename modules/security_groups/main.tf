variable "infra_name" {}
variable "vpc_id" {}
variable "bootstrap_port" {}

resource "aws_security_group" "ssh_access" {
  name        = "${var.infra_name}-ssh_access"
  description = "Allow all ssh access"
  vpc_id = "${var.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "consul_member" {
  name        = "${var.infra_name}-consul_member"
  description = "Consul member"
  vpc_id = "${var.vpc_id}"

  ingress {
    from_port = 8300
    to_port   = 8302
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port = 8300
    to_port   = 8302
    protocol  = "udp"
    self      = true
  }

  ingress {
    from_port = 8400
    to_port   = 8400
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port = 8400
    to_port   = 8400
    protocol  = "udp"
    self      = true
  }

  ingress {
    from_port = 8500
    to_port   = 8500
    protocol  = "tcp"
    self      = true
  }

  ingress {
    from_port = 8600
    to_port   = 8600
    protocol  = "tcp"
    self      = true
  }

  #  ingress {
  #    from_port = 8600
  #    to_port = 8600
  #    protocol = "udp"
  #    self = true
  #  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "bootstrap_http" {
  name        = "${var.infra_name}-bootstrap_http"
  description = "DCOS bootstrap machine HTTP access"
  vpc_id = "${var.vpc_id}"

  ingress {
    from_port       = 2181
    to_port         = 2181
    protocol        = "tcp"
    security_groups = ["${aws_security_group.dcos_member.id}"]
  }

  ingress {
    from_port       = "${var.bootstrap_port}"
    to_port         = "${var.bootstrap_port}"
    protocol        = "tcp"
    security_groups = ["${aws_security_group.dcos_member.id}"]
  }
}

resource "aws_security_group" "dcos_member" {
  name        = "${var.infra_name}-dcos_member"
  description = "DCOS cluster member"
  vpc_id = "${var.vpc_id}"

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }
}

resource "aws_security_group" "dcos_worker" {
  name        = "${var.infra_name}-dcos_worker"
  description = "DCOS slave access"
  vpc_id = "${var.vpc_id}"

  ingress {
    from_port   = 1
    to_port     = 21
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 23
    to_port     = 5050
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5052
    to_port     = 32000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "dcos_edge" {
  name        = "${var.infra_name}-dcos_edge"
  description = "DCOS slave public access"
  vpc_id = "${var.vpc_id}"

  ingress {
    from_port   = 1
    to_port     = 21
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 23
    to_port     = 5050
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5052
    to_port     = 32000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "dcos_control-insecure" {
  name        = "${var.infra_name}-dcos_control-insecure"
  description = "DCOS control, normally authentication required"
  vpc_id = "${var.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5050
    to_port     = 5050
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8181
    to_port     = 8181
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

output "ssh_access_security_group" {
  value = "${aws_security_group.ssh_access.id}"
}

output "consul_member_security_group" {
  value = "${aws_security_group.consul_member.id}"
}

output "bootstrap_http_security_group" {
  value = "${aws_security_group.bootstrap_http.id}"
}

output "dcos_member_security_group" {
  value = "${aws_security_group.dcos_member.id}"
}

output "dcos_worker_security_group" {
  value = "${aws_security_group.dcos_worker.id}"
}

output "dcos_edge_security_group" {
  value = "${aws_security_group.dcos_edge.id}"
}

output "dcos_control_security_group" {
  value = "${aws_security_group.dcos_control-insecure.id}"
}

