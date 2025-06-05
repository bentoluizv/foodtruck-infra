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
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
    read_only      = true
  }
  volumes {
    host_path      = "${abspath(path.module)}/letsencrypt"
    container_path = "/letsencrypt"
  }

  command = [
    "--log.level=DEBUG",
    "--api.insecure=true",
    "--providers.docker=true",
    "--providers.docker.exposedbydefault=false",
    "--entryPoints.web.address=:80",
    "--entryPoints.websecure.address=:443",
    "--certificatesresolvers.myresolver.acme.httpchallenge=true",
    "--certificatesresolvers.myresolver.acme.httpchallenge.entrypoint=web",
    "--certificatesresolvers.myresolver.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory",
    "--certificatesresolvers.myresolver.acme.email=bentomachado@gmail.com",
    "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
  ]

  restart = "unless-stopped"
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
    value = "Host(`whoami.bentomachado.dev`)"
  }
  labels {
    label = "traefik.http.routers.whoami.entrypoints"
    value = "websecure"
  }
  labels {
    label = "traefik.http.routers.whoami.tls.certresolver"
    value = "myresolver"
  }
}
