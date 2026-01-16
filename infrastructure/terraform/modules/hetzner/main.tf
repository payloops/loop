terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }
}

variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "location" {
  description = "Hetzner datacenter location"
  type        = string
  default     = "nbg1" # Nuremberg
}

variable "ssh_keys" {
  description = "List of SSH key IDs"
  type        = list(string)
}

variable "web_server_type" {
  description = "Server type for web/API servers"
  type        = string
  default     = "cx31" # 2 vCPU, 8GB RAM
}

variable "worker_server_type" {
  description = "Server type for worker servers"
  type        = string
  default     = "cx41" # 4 vCPU, 16GB RAM
}

variable "db_server_type" {
  description = "Server type for database server"
  type        = string
  default     = "cx41"
}

provider "hcloud" {
  token = var.hcloud_token
}

# Private network for internal communication
resource "hcloud_network" "loop" {
  name     = "loop-${var.environment}"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "loop" {
  network_id   = hcloud_network.loop.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.1.0/24"
}

# Firewall rules
resource "hcloud_firewall" "web" {
  name = "loop-web-${var.environment}"

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

resource "hcloud_firewall" "internal" {
  name = "loop-internal-${var.environment}"

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "any"
    source_ips = ["10.0.0.0/16"]
  }

  rule {
    direction = "in"
    protocol  = "tcp"
    port      = "22"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}

# Web/API servers
resource "hcloud_server" "web" {
  count       = 2
  name        = "loop-web-${var.environment}-${count.index + 1}"
  server_type = var.web_server_type
  image       = "ubuntu-24.04"
  location    = var.location
  ssh_keys    = var.ssh_keys
  firewall_ids = [hcloud_firewall.web.id]

  labels = {
    environment = var.environment
    role        = "web"
  }

  network {
    network_id = hcloud_network.loop.id
    ip         = "10.0.1.${10 + count.index}"
  }

  depends_on = [hcloud_network_subnet.loop]
}

# Worker servers (Temporal workers)
resource "hcloud_server" "worker" {
  count       = 1
  name        = "loop-worker-${var.environment}-${count.index + 1}"
  server_type = var.worker_server_type
  image       = "ubuntu-24.04"
  location    = var.location
  ssh_keys    = var.ssh_keys
  firewall_ids = [hcloud_firewall.internal.id]

  labels = {
    environment = var.environment
    role        = "worker"
  }

  network {
    network_id = hcloud_network.loop.id
    ip         = "10.0.1.${20 + count.index}"
  }

  depends_on = [hcloud_network_subnet.loop]
}

# Database server
resource "hcloud_server" "db" {
  name        = "loop-db-${var.environment}"
  server_type = var.db_server_type
  image       = "ubuntu-24.04"
  location    = var.location
  ssh_keys    = var.ssh_keys
  firewall_ids = [hcloud_firewall.internal.id]

  labels = {
    environment = var.environment
    role        = "database"
  }

  network {
    network_id = hcloud_network.loop.id
    ip         = "10.0.1.30"
  }

  depends_on = [hcloud_network_subnet.loop]
}

# Redis server
resource "hcloud_server" "redis" {
  name        = "loop-redis-${var.environment}"
  server_type = "cx21" # 2 vCPU, 4GB RAM
  image       = "ubuntu-24.04"
  location    = var.location
  ssh_keys    = var.ssh_keys
  firewall_ids = [hcloud_firewall.internal.id]

  labels = {
    environment = var.environment
    role        = "redis"
  }

  network {
    network_id = hcloud_network.loop.id
    ip         = "10.0.1.31"
  }

  depends_on = [hcloud_network_subnet.loop]
}

# Temporal server
resource "hcloud_server" "temporal" {
  name        = "loop-temporal-${var.environment}"
  server_type = "cx31"
  image       = "ubuntu-24.04"
  location    = var.location
  ssh_keys    = var.ssh_keys
  firewall_ids = [hcloud_firewall.internal.id]

  labels = {
    environment = var.environment
    role        = "temporal"
  }

  network {
    network_id = hcloud_network.loop.id
    ip         = "10.0.1.32"
  }

  depends_on = [hcloud_network_subnet.loop]
}

# Load balancer
resource "hcloud_load_balancer" "web" {
  name               = "loop-lb-${var.environment}"
  load_balancer_type = "lb11"
  location           = var.location

  labels = {
    environment = var.environment
  }
}

resource "hcloud_load_balancer_network" "web" {
  load_balancer_id = hcloud_load_balancer.web.id
  network_id       = hcloud_network.loop.id
  ip               = "10.0.1.5"
}

resource "hcloud_load_balancer_target" "web" {
  count            = 2
  type             = "server"
  load_balancer_id = hcloud_load_balancer.web.id
  server_id        = hcloud_server.web[count.index].id
  use_private_ip   = true

  depends_on = [hcloud_load_balancer_network.web]
}

resource "hcloud_load_balancer_service" "https" {
  load_balancer_id = hcloud_load_balancer.web.id
  protocol         = "https"
  listen_port      = 443
  destination_port = 3000

  http {
    certificates = [] # Add SSL certificate IDs here
  }

  health_check {
    protocol = "http"
    port     = 3000
    interval = 10
    timeout  = 5
    retries  = 3
    http {
      path = "/health"
    }
  }
}

# Outputs
output "web_server_ips" {
  value = hcloud_server.web[*].ipv4_address
}

output "worker_server_ips" {
  value = hcloud_server.worker[*].ipv4_address
}

output "db_server_ip" {
  value = hcloud_server.db.ipv4_address
}

output "redis_server_ip" {
  value = hcloud_server.redis.ipv4_address
}

output "temporal_server_ip" {
  value = hcloud_server.temporal.ipv4_address
}

output "load_balancer_ip" {
  value = hcloud_load_balancer.web.ipv4
}

output "private_network_id" {
  value = hcloud_network.loop.id
}
