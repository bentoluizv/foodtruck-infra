# Rede Docker dedicada
resource "docker_network" "traefik" {
  name   = "traefik"
  driver = "bridge"
}

resource "docker_container" "traefik" {
  name  = "traefik"
  image = docker_image.traefik.image_id

  networks_advanced {
    name    = docker_network.traefik.name
    aliases = ["traefik"]
  }

  restart = "unless-stopped"

  ports {
    internal = 80
    external = 80
  }
  ports {
    internal = 443
    external = 443
  }
  ports {
    internal = 8080
    external = 8080
  }

  volumes {
    host_path      = "${abspath(path.module)}/traefik.yml"
    container_path = "/etc/traefik/traefik.yml"
    read_only      = true
  }
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }
  volumes {
    host_path      = "${abspath(path.module)}/acme"
    container_path = "/acme"
  }
}

resource "docker_container" "whoami" {
  name  = "whoami"
  image = docker_image.whoami.image_id

  networks_advanced {
    name    = docker_network.traefik.name
    aliases = ["whoami"]
  }

  restart = "unless-stopped"

  labels {
    label = "traefik.enable"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.whoami.rule"
    value = "Host(`whoami.bentomachado.dev`) || Host(`whoami.localhost`)"
  }

  labels {
    label = "traefik.http.routers.whoami.entrypoints"
    value = "websecure"
  }

  labels {
    label = "traefik.http.routers.whoami.tls"
    value = "true"
  }

  labels {
    label = "traefik.http.routers.whoami.tls.certresolver"
    value = "myresolver"
  }
}
