provider "aws" {
  region = "us-east-2"
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.2.0"
}

terraform {
  backend "s3" {
    bucket  = "qnt-clouds-for-pe-tfstate"
    key     = "ivakhitov/terraform.tfstate"
    region  = "us-east-2"
    encrypt = true
  }
}

data "aws_ami" "ubuntu" {

  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

locals {
  ubuntu_ami_id     = data.aws_ami.ubuntu.id
  security_group_id = ""
}

# Resources

# Security group
resource "aws_security_group" "sg_vakhitov_terraform" {
  name   = "sg_vakhitov_terraform"
  vpc_id = var.vpc_id

  tags = {
    Name = "Vakhitov Terraform"
    env  = "dev"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip}/32"]
  }

}

# S3 bucket
resource "aws_s3_bucket" "qnt-bucket-tf-ilya-vakhitov" {
  bucket = "qnt-bucket-tf-ilya-vakhitov"

  tags = {
    Name = "Terraform Vakhitov"
    env  = "dev"
  }
}

# IAM role

data "aws_iam_policy_document" "allow_assume_role_ec2" {

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "allow_access_to_s3" {
  statement {
    effect = "Allow"

    actions = [
      "s3:*",
    ]

    resources = [
      aws_s3_bucket.qnt-bucket-tf-ilya-vakhitov.arn,
      "${aws_s3_bucket.qnt-bucket-tf-ilya-vakhitov.arn}/*",
    ]
  }
}

resource "aws_iam_role" "ec2_vakhitov_terraform_role" {
  name = "ec2_vakhitov_terraform_role"
  depends_on = [
    aws_s3_bucket.qnt-bucket-tf-ilya-vakhitov
  ]

  assume_role_policy = data.aws_iam_policy_document.allow_assume_role_ec2.json

  tags = {
    Name = "Vakhitov Terraform"
    env  = "dev"
  }
}

resource "aws_iam_role_policy" "vakhitov_terraform_s3_policy" {
  name = "vakhitov_terraform_policy"
  role = aws_iam_role.ec2_vakhitov_terraform_role.id

  policy = data.aws_iam_policy_document.allow_access_to_s3.json
}

# IAM profile
resource "aws_iam_instance_profile" "vakhitov_terraform_role_profile" {
  name = "vakhitov_terraform_role_profile"
  role = aws_iam_role.ec2_vakhitov_terraform_role.name
}

# EC2 instance

resource "aws_instance" "ec2_vakhitov_terraform" {
  ami                         = local.ubuntu_ami_id
  instance_type               = "t3a.small"
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.sg_vakhitov_terraform.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.vakhitov_terraform_role_profile.name
  key_name                    = var.key_name
  user_data                   = file("user_data.sh")

  depends_on = [
    aws_iam_instance_profile.vakhitov_terraform_role_profile,
    aws_iam_role.ec2_vakhitov_terraform_role
  ]

  tags = {
    Name    = "ec2_vakhitov_terraform"
    env     = "dev"
    owner   = "ilya.vakhitov@quantori.com"
    project = "INFRA"
  }
}

# EC2 instance state
resource "aws_ec2_instance_state" "ec2_vakhitov_terraform_state" {
  instance_id = aws_instance.ec2_vakhitov_terraform.id
  state       = "stopped"
}
