variable "infra_name" {default = "dcosProto"}
variable "instance_counts" {type = "map"}
variable "role" {}
variable "count_format" {default = "%02d"}
variable "ec2_type" {default = "m3.medium"}
variable "ebs_volume_size" {default = "20"} # size is in gigabytes
variable "ebs_volume_type" {default = "gp2"}
variable "data_ebs_volume_size" {default = "20"} # size is in gigabytes
variable "data_ebs_volume_type" {default = "gp2"}
variable "iam_profile" {default = "" }
variable "datacenter" {}
variable "source_ami" {}
variable "availability_zones" {}
variable "vpc_subnet_ids" { type = "list" }
variable "vpc_security_group_ids" { type = "list" }
variable "ssh_username" {default = "centos"}
variable "ssh_key_pair" {}
variable "ssh_private_key" {}
variable "spot_price" {}

variable "bootstrap_dns" {default = ""}
variable "bootstrap_public_ip" {default = ""}
variable "bootstrap_port" {default = "10000"}
variable "provisioner_directory" {}

resource "aws_ebs_volume" "ebs" {
  availability_zone = "${element(split(",", var.availability_zones), count.index%length(split(",", var.availability_zones)))}"
  count = "${var.data_ebs_volume_size != "0" ? lookup(var.instance_counts, var.role) : 0}"
  size = "${var.data_ebs_volume_size}"
  type = "${var.data_ebs_volume_type}"

  tags {
    Name = "${var.infra_name}-${var.role}-lvm-${format(var.count_format, count.index+1)}"
  }
}

# TODO: Modify the VPC setup to add NAT translation and to draw a distinction
#       between public/private subnets, then toggle the positive case for
#       associate_public_ip_address from true to false.  For now, SSH access
#       is still restricted through the bootstrap instance, but the worker
#       nodes could not make outbound connections without receiving a public
#       IP address...
resource "aws_spot_instance_request" "instance" {
  ami = "${var.source_ami}"
  instance_type = "${var.ec2_type}"
  count = "${lookup(var.instance_counts, var.role)}"
  vpc_security_group_ids = ["${var.vpc_security_group_ids}"]
  key_name = "${var.ssh_key_pair}"
  associate_public_ip_address = true
  subnet_id = "${element(var.vpc_subnet_ids, count.index%length(var.vpc_subnet_ids))}" 
  iam_instance_profile = "${var.iam_profile}"
  root_block_device {
    delete_on_termination = true
    volume_size = "${var.ebs_volume_size}"
    volume_type = "${var.ebs_volume_type}"
  }
  tags {
    Name = "${var.infra_name}-${var.role}-${format(var.count_format, count.index+1)}"
    sshUser = "${var.ssh_username}"
    role = "${var.role}"
    dc = "${var.datacenter}"
  }
  spot_price = "${var.spot_price}"
  wait_for_fulfillment = true

  # Following directives ported as-is from dcos-up project, but should later
  # be migrated to a post-terraform Ansible step
  connection {
    type         = "ssh"
    user         = "${var.ssh_username}"
    host         = "${var.role == "bootstrap" ? "${self.public_dns}" : "${self.private_ip}"}"
    bastion_host = "${var.role == "bootstrap" ? "" : "${var.bootstrap_public_ip}"}"
    private_key  = "${var.ssh_private_key}"
    agent        = false
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p ${var.provisioner_directory}",
      "echo export BOOTSTRAP_NODE_ADDRESS=${var.role == "bootstrap" ? "${self.private_dns}" : "${var.bootstrap_dns}"} > ${var.provisioner_directory}/vars",
      "echo export BOOTSTRAP_PORT=${var.bootstrap_port} >> ${var.provisioner_directory}/vars",
      "echo export EXPECTED_MASTER_COUNT=${lookup(var.instance_counts, "control")} >> ${var.bootstrap_dns != "" ? "/dev/null" : "${var.provisioner_directory}/vars"}",
      "echo export EXPECTED_AGENT_COUNT=${lookup(var.instance_counts, "worker") + lookup(var.instance_counts, "edge")} >> ${var.bootstrap_dns != "" ? "/dev/null" : "${var.provisioner_directory}/vars"}",
      "echo export DATACENTER=${var.datacenter} >> ${var.provisioner_directory}/vars",
      "echo export NODE_NAME=${var.infra_name}-${var.role}-${format(var.count_format, count.index+1)} >> ${var.provisioner_directory}/vars",
      "echo export IS_CONSUL_SERVER=${var.bootstrap_dns != "" ? false : true} >> ${var.provisioner_directory}/vars",
      "echo export IS_BOOTSTRAP_SERVER=${var.bootstrap_dns != "" ? false : true} >> ${var.provisioner_directory}/vars",
      "echo export IPV4_PRIVATE=${self.private_ip} >> ${var.provisioner_directory}/vars",
      "echo export IPV4_PUBLIC=${self.public_ip} >> ${var.provisioner_directory}/vars",
      "echo export DCOS_NODE_TYPE=${var.role} >> ${var.provisioner_directory}/vars"
    ]
  }

  provisioner "file" {
    source      = "${path.module}/provision/"
    destination = "${var.provisioner_directory}"
  }

  provisioner "remote-exec" {
    inline = [
      "cd ${var.provisioner_directory} && chmod +x prepare-dcos-machine.sh && ./prepare-dcos-machine.sh"
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "cd ${var.provisioner_directory} && chmod +x setup-consul.sh && ./setup-consul.sh"
    ]
  }
}


resource "aws_volume_attachment" "instance-lvm-attachment" {
  count = "${var.data_ebs_volume_size != "0" ? lookup(var.instance_counts, var.role) : 0}"
  device_name = "xvdh"
  instance_id = "${element(aws_spot_instance_request.instance.*.spot_instance_id, count.index)}"
  volume_id = "${element(aws_ebs_volume.ebs.*.id, count.index)}"
  force_detach = true
}



output "hostname_list" {
  value = "${join(",", aws_spot_instance_request.instance.*.tags.Name)}"
}

output "ec2_ids" {
  value = "${join(",", aws_spot_instance_request.instance.*.spot_instance_id)}"
}

output "ec2_public_ips" {
  value = "${join(",", aws_spot_instance_request.instance.*.public_ip)}"
}

output "ec2_private_dns" {
  value = "${join(",", aws_spot_instance_request.instance.*.private_dns)}"
}
