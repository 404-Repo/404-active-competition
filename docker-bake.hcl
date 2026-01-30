variable "VERSION" {
  default = "1.0.0"
}

variable "REGISTRY_NAME" {
  default = "competition-1"
}

variable "GITHUB_TOKEN" {
  default = ""
}

variable "GITHUB_USER" {
  default = ""
}

variable "HUGGINGFACE_TOKEN" {
  default = ""
}

variable "CONTEXT" {
  default = ""
}

variable "MINER_HOTKEY" {
  default = ""
}

variable "DOCKERFILE" {
  default = "docker/Dockerfile"
}

variable "CACHE_FROM" {
  default = ""
}

variable "CACHE_TO" {
  default = ""
}

group "default" {
  targets = ["gen404-image"]
}

target "gen404-image" {
  platforms  = ["linux/amd64"]
  context = CONTEXT
  dockerfile = DOCKERFILE
  args = {
    GITHUB_USER = GITHUB_USER
    GITHUB_TOKEN = GITHUB_TOKEN
  }
  secret = [
    "id=github_token,env=GITHUB_TOKEN"
  ]
  cache-from = split(";", CACHE_FROM)
  cache-to = split(";", CACHE_TO)
  tags = [
    "europe-docker.pkg.dev/gen-456515/${REGISTRY_NAME}/${MINER_HOTKEY}:${VERSION}",
  ]
}