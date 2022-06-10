terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.24.0"
    }
  }
  backend "gcs" { }
}

provider "google" {
  credentials = file("../credentials.json")

  project = var.project_id
  region  = var.region_name
  zone    = "europe-west-3b"
}

resource "google_sql_database" "database" {
  name     = "${var.project_name}_app"
  instance = google_sql_database_instance.instance.name
}

resource "google_sql_database_instance" "instance" {
  name             = "${var.project_name}-sql-${var.env_tag}" 
  region           = var.region_name
  database_version = var.sql_version
  settings {
    tier = "db-f1-micro"
  }

  deletion_protection  = "false"
}

resource "random_password" "sql_user_pass" {
  length = 32
  special = false
}

resource "google_sql_user" "user" {
  name     = "admin"
  instance = google_sql_database_instance.instance.name
  password = random_password.sql_user_pass.result
}

resource "google_storage_bucket" "storage_bucket" {
  name             = "${var.project_name}-storage-${var.env_tag}" 
  location      = var.region_name
  force_destroy = true

  uniform_bucket_level_access = false

  cors {
    origin          = ["*"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }
}

resource "google_secret_manager_secret" "rails_master_key_secret" {
  # IMPORT with following command
  # terraform import google_secret_manager_secret.rails_master_key_secret $RAILS_SECRET_KEY
  secret_id = "${var.project_name}-secret-${var.env_tag}"
  
  replication {
    user_managed {
      replicas {
        location = var.region_name
      }
    }
  }
}

resource "google_secret_manager_secret_version" "secret-version-basic" {
  secret = google_secret_manager_secret.rails_master_key_secret.id

  secret_data = var.master_key_secret
}

resource "google_cloud_run_service" "default" {
  name     = "${var.project_name}-${var.env_tag}"
  location = var.region_name

  template {
    spec {
      containers {
        image = "${var.region_name}-docker.pkg.dev/${var.project_id}/${var.project_name}/app:${var.env_tag_version}"
        env {
          name = "RAILS_ENV"
          value = var.rails_env
        }
        env {
          name = "DB_PASS"
          value = random_password.sql_user_pass.result
        }
        env {
          name = "DB_USER"
          value = google_sql_user.user.name
        }
        env {
          name = "DB_NAME"
          value = google_sql_database.database.name
        }
        env {
          name = "DB_HOST"
          value = "/cloudsql/${google_sql_database_instance.instance.connection_name}"
        }
        env {
          name = "DEVISE_JWT_SECRET_KEY"
          value = "12390139123801239"
        }
      }
    }
    metadata {
      annotations = {
        "run.googleapis.com/cloudsql-instances" = google_sql_database_instance.instance.connection_name
        "run.googleapis.com/client-name" = "terraform"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
  autogenerate_revision_name = true
}

resource "google_compute_region_network_endpoint_group" "cloudrun_neg" {
  count = var.requires_load_balancer ? 1 : 0
  name                  = "${var.project_name}-${var.env_tag}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region_name
  cloud_run {
    service = google_cloud_run_service.default.name
  }
}

module "lb-http" {
  count = var.requires_load_balancer ? 1 : 0
  source            = "GoogleCloudPlatform/lb-http/google//modules/serverless_negs"
  version           = "6.2.0"

  project           = var.project_id
  name              = "${var.project_name}-${var.env_tag}"

  managed_ssl_certificate_domains = ["${var.env_tag}.app.${var.domain}"]
  ssl                             = true
  https_redirect                  = true

  backends = {
    default = {
      # List your serverless NEGs, VMs, or buckets as backends
      groups = [
        {
          group = google_compute_region_network_endpoint_group.cloudrun_neg[0].id
        }
      ]

      enable_cdn = false

      log_config = {
        enable      = true
        sample_rate = 1.0
      }

      iap_config = {
        enable               = false
        oauth2_client_id     = null
        oauth2_client_secret = null
      }

      description             = null
      custom_request_headers  = null
      custom_response_headers  = null
      security_policy         = null
    }
  }
}

resource "google_dns_record_set" "a" {
    count = var.requires_load_balancer ? 1 : 0
    name = "${var.env_tag}.app.${var.domain}."
    managed_zone = "${var.project_name}-app"
    type = "A"
    ttl = 300
    rrdatas = [module.lb-http[0].external_ip]
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location    = google_cloud_run_service.default.location
  project     = google_cloud_run_service.default.project
  service     = google_cloud_run_service.default.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

output "cloud_run_url" {
  value = google_cloud_run_service.default.status[0].url
}
