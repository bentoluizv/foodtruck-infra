terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.6.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Imagem do Traefik (versão 2.x)
resource "docker_image" "traefik" {
  name = "traefik:v3.4.1"
}

# Imagem do whoami (serve para teste de roteamento)
resource "docker_image" "whoami" {
  name = "traefik/whoami:latest"
}

