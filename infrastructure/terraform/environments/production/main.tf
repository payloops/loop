terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "loop-terraform-state"
    key            = "production/terraform.tfstate"
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
  environment        = "production"
  location           = "nbg1"
  ssh_keys           = var.ssh_key_ids
  web_server_type    = "cx31"  # 2 vCPU, 8GB RAM
  worker_server_type = "cx41"  # 4 vCPU, 16GB RAM
  db_server_type     = "cx41"  # 4 vCPU, 16GB RAM
}

output "web_servers" {
  value = module.infrastructure.web_server_ips
}

output "worker_servers" {
  value = module.infrastructure.worker_server_ips
}

output "database_server" {
  value = module.infrastructure.db_server_ip
}

output "redis_server" {
  value = module.infrastructure.redis_server_ip
}

output "temporal_server" {
  value = module.infrastructure.temporal_server_ip
}

output "load_balancer" {
  value = module.infrastructure.load_balancer_ip
}
