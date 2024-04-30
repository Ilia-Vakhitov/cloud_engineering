variable "vpc_id" {
  type        = string
  description = "VPC ID"
}
variable "subnet_id" {
  type        = string
  description = "Subnet ID for given VPC"
}

variable "my_ip" {
  type        = string
  description = "ID to allow traffic to EC2"
}

variable "key_name" {
  type        = string
  description = "Key pair to connect to EC2"
}
