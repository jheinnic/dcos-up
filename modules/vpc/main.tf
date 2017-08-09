variable "availability_zones"  {
  default = "b,c"
}
variable "cidr_blocks" {
  default = {
    az0 = "10.1.9.0/24"
    az1 = "10.1.10.0/24"
    az2 = "10.1.11.0/24"
  }
}
variable "infra_name" {default = "dcosProto"}
variable "long_name" {default = "dcos_consul.proto"}
variable "vpc_cidr" {default = "10.1.8.0/21"}
variable "region" {}
variable "datacenter" {}



resource "aws_vpc" "default" {
  cidr_block = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  tags {
    Name = "${var.long_name}"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.default.id}"
  tags {
    Name = "${var.long_name}"
  }
}

resource "aws_route_table" "default" {
  vpc_id = "${aws_vpc.default.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
  tags {
    Name = "${var.long_name}"
  }
}

resource "aws_main_route_table_association" "default" {
  vpc_id = "${aws_vpc.default.id}"
  route_table_id = "${aws_route_table.default.id}"
}

resource "aws_subnet" "default" {
  vpc_id = "${aws_vpc.default.id}"
  count = "${length(split(",", var.availability_zones))}"
  cidr_block = "${lookup(var.cidr_blocks, "az${count.index}")}"
  map_public_ip_on_launch = true
  availability_zone = "${var.region}${element(split(",", var.availability_zones), count.index)}"
  tags {
    Name = "${var.long_name}"
  }
}

resource "aws_route_table_association" "default" {
  count = "${length(split(",", var.availability_zones))}"
  subnet_id = "${element(aws_subnet.default.*.id, count.index)}"
  route_table_id = "${aws_route_table.default.id}"
}

output "availability_zones" {
  value = "${join(",",aws_subnet.default.*.availability_zone)}"
}

output "subnet_ids" {
  value = ["${aws_subnet.default.*.id}"]
}

output "default_security_group" {
  value = "${aws_vpc.default.default_security_group_id}"
}

output "vpc_id" {
  value = "${aws_vpc.default.id}"
}
