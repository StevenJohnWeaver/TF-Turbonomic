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
  description = "The hostname for the Turbonomic instance"
  type        = string
  sensitive   = false
}

data "turbonomic_cloud_entity_recommendation" "example" {
  entity_name  = "exampleVirtualMachineEC2"
  entity_type  = "VirtualMachine"
  default_size = "t3.nano"
}

resource "aws_instance" "terraform-turbo-demo-ec2" {
  ami           = "ami-0de716d6197524dd9"
  instance_type = data.turbonomic_cloud_entity_recommendation.example.new_instance_type
  tags = merge(
    {
      Name     = "exampleVirtualMachineEC2"
      DemoPath = "auto-provider"
    },
    provider::turbonomic::get_tag()
  )
}

check "turbonomic_consistent_with_recommendation_check" {
  assert {
    # Reference the correct resource name
    condition = aws_instance.terraform-turbo-demo-ec2.instance_type == coalesce(data.turbonomic_cloud_entity_recommendation.example.new_instance_type, aws_instance.terraform-turbo-demo-ec2.instance_type)
    error_message = "Must use the latest recommended instance type, ${coalesce(data.turbonomic_cloud_entity_recommendation.example.new_instance_type, aws_instance.terraform-turbo-demo-ec2.instance_type)}"
  }
}

# Governed path: instance type is hard-coded and only changed through a
# reviewed PR. Turbonomic raises a GitHub issue for each scale action on this
# VM (policy scoped to the DemoPath = github-issue tag).
resource "aws_instance" "governed-demo-ec2" {
  ami           = "ami-0de716d6197524dd9"
  instance_type = "t3.medium"
  tags = {
    Name     = "exampleGovernedVM"
    DemoPath = "github-issue"
  }
}

data "turbonomic_cloud_entity_recommendation" "governed" {
  entity_name  = "exampleGovernedVM"
  entity_type  = "VirtualMachine"
  default_size = "t3.medium"
}

check "governed_vm_matches_recommendation_check" {
  assert {
    condition     = aws_instance.governed-demo-ec2.instance_type == coalesce(data.turbonomic_cloud_entity_recommendation.governed.new_instance_type, aws_instance.governed-demo-ec2.instance_type)
    error_message = "Turbonomic recommends ${coalesce(data.turbonomic_cloud_entity_recommendation.governed.new_instance_type, aws_instance.governed-demo-ec2.instance_type)} for exampleGovernedVM; resize via a PR that closes the open Turbonomic issue"
  }
}
