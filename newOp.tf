variable "infra_name" {
  type    = "string"
  default = "dcosProto"
}

variable "long_name" {
  type    = "string"
  default = "dcos_consul.proto"
}

variable "region" {
  type    = "string"
  default = "us-west-2"
}

variable "availability_zones" {
  type    = "string"
  default = "b,c"
}

variable "datacenter" {
  type    = "string"
  default = "aws-us-west-2"
}

variable "spot_price" {
  default = "0.0525"
}

variable "ami_ids" {
  type = "map"

  default {
    us-east-1      = "ami-6d1c2007"
    us-west-1      = "ami-af4333cf"
    us-west-2      = "ami-d2c924b2"
    eu-central-1   = "ami-9bf712f4"
    eu-west-1      = "ami-7abd0209"
    ap-southeast-1 = "ami-f068a193"
    ap-southeast-2 = "ami-fedafc9d"
    ap-northeast-1 = "ami-eec1c380"
    ap-northeast-2 = "ami-c74789a9"
    sa-east-1      = "ami-26b93b4a"
  }
}

variable "instance_types" {
  type = "map"

  default = {
    bootstrap    = "m3.medium"
    control      = "m3.medium"
    worker       = "m3.xlarge"
    edge         = "c3.large"
  }
}

variable "root_volume_types" {
  type = "map"

  default = {
    bootstrap    = "gp2"
    control      = "gp2"
    worker       = "gp2"
    edge         = "gp2"
  }
}

variable "root_block_sizes" {
  type = "map"

  default = {
    bootstrap    = "32"
    control      = "32"
    worker       = "80"
    edge         = "32"
  }
}

# NOTE: bootstrap should not really be configurable, but it makes the instance
#       module simpler to define if it looks that way here.
variable "instance_counts" {
  type = "map"

  default = {
    bootstrap    = 1
    control      = 1
    worker       = 4
    edge         = 1
  }
}

variable "dns_subdomain" {
  type = "string"
  default = ".dcosproto"
}
variable "dns_domain" {
  type = "string"
  default = "jchein.name"
}
variable "dns_zone_id" {
  type = "string"
  default = "ZZDGFM3FWZ1G9"
}


variable "provisioner" {
  type = "map"

  default = {
    username  = "centos"
    key_name  = "dcosProto"
    directory = "/home/centos/provision"
  }
}

variable "bootstrap_port" {
  type    = "string"
  default = "10000"
}

# MANTL-BASED VPC:

provider "aws" {
  region = "${var.region}"
}

module "vpc" {
  source = "./modules/vpc"
  availability_zones = "${var.availability_zones}"
  infra_name = "${var.infra_name}"
  long_name  = "${var.long_name}"
  vpc_cidr = "172.20.192.0/18"
  cidr_blocks = {
    az0 = "172.20.200.0/21"
    az1 = "172.20.208.0/21"
    az2 = "172.20.216.0/21"
  }
  datacenter = "${var.datacenter}"
  region = "${var.region}"
}

module "ssh-key" {
  source ="./modules/ssh"
  infra_name = "${var.infra_name}"
  ssh_key    = "~/.ssh/${var.infra_name}.pub"
}

module "security-groups" {
  source = "./modules/security_groups"
  infra_name = "${var.infra_name}"
  vpc_id = "${module.vpc.vpc_id}"
  bootstrap_port = "${var.bootstrap_port}"
}

module "bootstrap-node" {
  source = "./modules/instance"
  instance_counts = "${var.instance_counts}"
  count_format = "%02d"
  infra_name = "${var.infra_name}"
  datacenter = "${var.datacenter}"
  role = "bootstrap"
  ec2_type = "${lookup(var.instance_types, "bootstrap")}"
  ebs_volume_type = "${lookup(var.root_volume_types, "bootstrap")}"
  ebs_volume_size = "${lookup(var.root_block_sizes, "bootstrap")}"
  data_ebs_volume_size = "0",
  source_ami = "${lookup(var.ami_ids, var.region)}"
  availability_zones = "${module.vpc.availability_zones}"
  vpc_subnet_ids = "${module.vpc.subnet_ids}"
  vpc_security_group_ids = ["${module.vpc.default_security_group}", "${module.security-groups.ssh_access_security_group}", "${module.security-groups.consul_member_security_group}", "${module.security-groups.bootstrap_http_security_group}"]
  ssh_username = "${lookup(var.provisioner, "username")}"
  ssh_key_pair = "${module.ssh-key.ssh_key_name}"
  ssh_private_key = "${file("keys/${lookup(var.provisioner,"key_name")}")}"
  provisioner_directory = "${lookup(var.provisioner, "directory")}"
  spot_price = "${var.spot_price}"
}

module "control-nodes" {
  source = "./modules/instance"
  instance_counts = "${var.instance_counts}"
  count_format = "%02d"
  infra_name = "${var.infra_name}"
  datacenter = "${var.datacenter}"
  role = "control"
  ec2_type = "${lookup(var.instance_types, "control")}"
  ebs_volume_type = "${lookup(var.root_volume_types, "control")}"
  ebs_volume_size = "${lookup(var.root_block_sizes, "control")}"
  source_ami = "${lookup(var.ami_ids, var.region)}"
  availability_zones = "${module.vpc.availability_zones}"
  vpc_subnet_ids = "${module.vpc.subnet_ids}"
  vpc_security_group_ids = ["${module.vpc.default_security_group}", "${module.security-groups.ssh_access_security_group}", "${module.security-groups.consul_member_security_group}", "${module.security-groups.dcos_member_security_group}", "${module.security-groups.dcos_control_security_group}"]
  ssh_username = "${lookup(var.provisioner, "username")}"
  ssh_key_pair = "${module.ssh-key.ssh_key_name}"
  ssh_private_key = "${file("keys/${lookup(var.provisioner,"key_name")}")}"
  bootstrap_public_ip = "${module.bootstrap-node.ec2_public_ips}"
  bootstrap_dns = "${module.bootstrap-node.ec2_private_dns}"
  provisioner_directory = "${lookup(var.provisioner, "directory")}"
  spot_price = "${var.spot_price}"
}

module "edge-nodes" {
  source = "./modules/instance"
  instance_counts = "${var.instance_counts}"
  count_format = "%02d"
  infra_name = "${var.infra_name}"
  datacenter = "${var.datacenter}"
  role = "edge"
  ec2_type = "${lookup(var.instance_types, "edge")}"
  ebs_volume_type = "${lookup(var.root_volume_types, "edge")}"
  ebs_volume_size = "${lookup(var.root_block_sizes, "edge")}"
  source_ami = "${lookup(var.ami_ids, var.region)}"
  availability_zones = "${module.vpc.availability_zones}"
  vpc_subnet_ids = "${module.vpc.subnet_ids}"
  vpc_security_group_ids = ["${module.vpc.default_security_group}", "${module.security-groups.ssh_access_security_group}", "${module.security-groups.consul_member_security_group}", "${module.security-groups.dcos_member_security_group}", "${module.security-groups.dcos_edge_security_group}"]
  ssh_username = "${lookup(var.provisioner, "username")}"
  ssh_key_pair = "${module.ssh-key.ssh_key_name}"
  ssh_private_key = "${file("keys/${lookup(var.provisioner,"key_name")}")}"
  bootstrap_public_ip = "${module.bootstrap-node.ec2_public_ips}"
  bootstrap_dns = "${module.bootstrap-node.ec2_private_dns}"
  provisioner_directory = "${lookup(var.provisioner, "directory")}"
  spot_price = "${var.spot_price}"
}

module "worker-nodes" {
  source = "./modules/instance"
  instance_counts = "${var.instance_counts}"
  count_format = "%03d"
  infra_name = "${var.infra_name}"
  datacenter = "${var.datacenter}"
  role = "worker"
  ec2_type = "${lookup(var.instance_types, "worker")}"
  ebs_volume_type = "${lookup(var.root_volume_types, "worker")}"
  ebs_volume_size = "${lookup(var.root_block_sizes, "worker")}"
  data_ebs_volume_size = "100"
  source_ami = "${lookup(var.ami_ids, var.region)}"
  availability_zones = "${module.vpc.availability_zones}"
  vpc_subnet_ids = "${module.vpc.subnet_ids}"
  vpc_security_group_ids = ["${module.vpc.default_security_group}", "${module.security-groups.ssh_access_security_group}", "${module.security-groups.consul_member_security_group}", "${module.security-groups.dcos_member_security_group}", "${module.security-groups.dcos_worker_security_group}"]
  ssh_username = "${lookup(var.provisioner, "username")}"
  ssh_key_pair = "${module.ssh-key.ssh_key_name}"
  ssh_private_key = "${file("keys/${lookup(var.provisioner,"key_name")}")}"
  bootstrap_public_ip = "${module.bootstrap-node.ec2_public_ips}"
  bootstrap_dns = "${module.bootstrap-node.ec2_private_dns}"
  provisioner_directory = "${lookup(var.provisioner, "directory")}"
  spot_price = "${var.spot_price}"
}


# module "route53" {
#   source = "./modules/route53/dns"
#   control_count = "${var.control_count}"
#   control_ips = "${module.control-nodes.ec2_public_ips}"
#   domain = "${var.dns_domain}"
#   edge_count = "${var.edge_count}"
#   edge_ips = "${module.edge-nodes.ec2_public_ips}"
#   elb_fqdn = "${module.aws-elb.fqdn}"
#   hosted_zone_id = "${var.dns_zone_id}"
#   infra_name = "${var.infra_name}"
#   subdomain = "${var.dns_subdomain}"
#   traefik_elb_fqdn = "${module.traefik-elb.fqdn}"
#   traefik_zone_id = "${module.traefik-elb.zone_id}"
#   worker_count = "${var.worker_count}"
#   worker_ips = "${module.worker-nodes.ec2_public_ips}"
#   kubeworker_count = "${var.kubeworker_count}"
#   kubeworker_ips = "${module.kubeworker-nodes.ec2_public_ips}"
# }

output "exhibitor_address" {
  value = "http://${element(split(",", module.control-nodes.ec2_public_ips), 0)}:8181/exhibitor/v1/ui/index.html"
}

output "dcos_ui_address" {
  value = "http://${element(split(",", module.control-nodes.ec2_public_ips), 0)}"
}

output "dcos_marathon_address" {
  value = "http://${element(split(",", module.control-nodes.ec2_public_ips), 0)}:8080"
}

output "dcos_mesos_address" {
  value = "http://${element(split(",", module.control-nodes.ec2_public_ips), 0)}/mesos"
}

output "worker ip addresses" {
  value = "${module.worker-nodes.ec2_public_ips}"
}

output "edge ip addresses" {
  value = "${module.edge-nodes.ec2_public_ips}"
}

output "control ip addresses" {
  value = "${module.control-nodes.ec2_public_ips}"
}

output "bootstrap_ip" {
  value = "${module.bootstrap-node.ec2_public_ips}"
}
