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
  entity_name  = "exampleVirtualMachine" // Name of the cloud entity (e.g., a virtual machine) to get recommendations for 
  entity_type  = "VirtualMachine" // Type of the cloud entity (e.g., VirtualMachine, Database, etc.) 
  default_size = "t3.nano" // Default instance size used if no recommendation is available. 
}

# Create an AWS EC2 instance
resource "aws_instance" "terraform-demo-ec2" { 
  ami           = "ami-0de716d6197524dd9" # This is a publicly available Amazon Linux 2 AMI
  instance_type = data.turbonomic_cloud_entity_recommendation.example.new_instance_type // Uses the recommended instance type from the Turbonomic data source. 
  tags = merge( 
    { 
      Name = "exampleVirtualMachine" // Sets the Name tag for easy identification 
    }, 
    provider::turbonomic::get_tag() //tag the resource as optimized by Turbonomic Provider for Terraform 
  ) 
}

check "turbonomic_consistent_with_recommendation_check"{
  assert {
    condition =  aws_instance.terraform-instance-1.instance_type == coalesce(data.turbonomic_cloud_entity_recommendation.example.new_instance_type,aws_instance.terraform-instance-1.instance_type)
    error_message = "Must use the latest recommended instance type,${coalesce(data.turbonomic_cloud_entity_recommendation.example.new_instance_type,aws_instance.terraform-instance-1.instance_type)}"
  }
}
