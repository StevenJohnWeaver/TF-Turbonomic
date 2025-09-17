terraform { 
  required_providers { 
    turbonomic = { 
      source  = "IBM/turbonomic" 
      version = "1.2.0"
    }
  }
} 
provider "turbonomic" {
  hostname = var.turbo_hostname
  username = var.turbo_username
  password = var.turbo_password
  skipverify = true
}
