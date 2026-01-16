terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "loop-terraform-state"
    key            = "staging/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "loop-terraform-locks"
  }
}

variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "ssh_key_ids" {
  description = "List of SSH key IDs"
  type        = list(string)
}

module "infrastructure" {
  source = "../../modules/hetzner"

  hcloud_token       = var.hcloud_token
  environment        = "staging"
  location           = "nbg1"
  ssh_keys           = var.ssh_key_ids
  web_server_type    = "cx21"  # 2 vCPU, 4GB RAM (smaller for staging)
  worker_server_type = "cx31"  # 2 vCPU, 8GB RAM
  db_server_type     = "cx21"  # 2 vCPU, 4GB RAM
}

output "web_servers" {
  value = module.infrastructure.web_server_ips
}

output "database_server" {
  value = module.infrastructure.db_server_ip
}

output "load_balancer" {
  value = module.infrastructure.load_balancer_ip
}
