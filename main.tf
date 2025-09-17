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
  hostname = "trbwwy9kt0916.use1cp09.turbonomic.ibmappdomain.cloud"
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

data "turbonomic_cloud_entity_recommendation" "example" {
  entity_name  = "exampleVirtualMachine"
  entity_type  = "VirtualMachine"
  default_size = "t3.nano"
}

resource "aws_instance" "terraform-demo-ec2" {
  ami           = "ami-0de716d6197524dd9"
  instance_type = data.turbonomic_cloud_entity_recommendation.example.new_instance_type
  tags = merge(
    {
      Name = "exampleVirtualMachine"
    },
    provider::turbonomic::get_tag()
  )
}

check "turbonomic_consistent_with_recommendation_check" {
  assert {
    # Reference the correct resource name
    condition = aws_instance.terraform-demo-ec2.instance_type == coalesce(data.turbonomic_cloud_entity_recommendation.example.new_instance_type, aws_instance.terraform-demo-ec2.instance_type)
    error_message = "Must use the latest recommended instance type, ${coalesce(data.turbonomic_cloud_entity_recommendation.example.new_instance_type, aws_instance.terraform-demo-ec2.instance_type)}"
  }
}
