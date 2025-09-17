terraform { 
  required_providers { 
    turbonomic = { 
      source  = "IBM/turbonomic" 
      version = "1.2.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
} 

provider "turbonomic" {
  hostname = var.turbo_hostname
  username = var.turbo_username
  password = var.turbo_password
  skipverify = true
}

provider "aws" {
  region = "us-east-1"
}

variable "turbo_username" {
  description = "The username for the Turbonomic instance"
  type        = string
  sensitive   = false
}

variable "turbo_password" {
  description = "The password for the Turbonomic instance"
  type        = string
  sensitive   = true
}

variable "turbo_hostname" {
  description = "The hostname for the AAP instance"
  type        = string
  sensitive   = false
}

# Create an AWS EC2 instance
resource "aws_instance" "web_server" {
  ami           = "ami-0de716d6197524dd9" # This is a publicly available Amazon Linux 2 AMI
  instance_type = "t2.small"
  tags = {
    Name = "HelloWorldServer"
  }
}
