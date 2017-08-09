variable "infra_name" {default = "mantl"}
variable "ssh_key" {default = "~/.ssh/mantl.pub"}

resource "aws_key_pair" "deployer" {
  key_name = "key-${var.infra_name}"
  public_key = "${file(var.ssh_key)}"
}

output "ssh_key_name" {
	value = "${aws_key_pair.deployer.key_name}"
}
