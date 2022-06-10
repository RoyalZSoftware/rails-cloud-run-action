terraform {
  required_providers {
    google = {
      source = "hashicorp/google-beta"
      version = "4.23.0"
    }
  }
  backend "gcs" {
    prefix = "global"
  }
}

provider "google" {
  credentials = file("../credentials.json")

  project = var.project_id
  region  = var.region_name
  zone    = "europe-west-3b"
}

resource "google_artifact_registry_repository" "docker-registry" {
  location = var.region_name
  repository_id = "${var.project_name}"
  description = "Docker registry for all images"
  format = "DOCKER"
  # europe-west3-docker.pkg.dev/test-project-42069123/royalzsoftware
}

resource "google_dns_managed_zone" "app_zone" {
  name        = "${var.project_name}-app"
  dns_name    = "app.${var.domain}."
  description = "DNS Zone for ${var.project_name} app"
}
