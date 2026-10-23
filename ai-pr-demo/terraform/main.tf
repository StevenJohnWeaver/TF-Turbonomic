terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# This is the "before" state the demo starts from: a Terraform-managed EC2
# instance with a hardcoded instance_type. A Turbonomic optimization action
# recommends a cheaper/better-fit type, and the AI workflow in
# ../webhook-service edits this file (not a data source) to match.
resource "aws_instance" "turbonomic_managed_vm" {
  ami           = "ami-0de716d6197524dd9"
  instance_type = "t3.micro"

  tags = {
    Name = "exampleVirtualMachine"
  }
}
