terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 7.0"
    }
  }
}

variable "project_id" {
  type = string
}

variable "billing_account_id" {
  type = string
}

provider "google" {
  region                = "europe-north1"
  user_project_override = true
  billing_project       = "project-91ffb8fd-9244-4305-b14"
}

resource "google_project" "twin" {
  name            = "VANTAA-Digital-Twin-0"
  project_id      = var.project_id
  billing_account = var.billing_account_id
  labels          = { app = "vdt" }
  deletion_policy = "DELETE"
}

output "project_id" {
  value = google_project.twin.project_id
}

output "project_number" {
  value = google_project.twin.number
}

resource "google_billing_budget" "monthly" {
  billing_account = var.billing_account_id
  display_name    = "vdt-monthly"

  budget_filter {
    projects               = ["projects/${google_project.twin.number}"]
    credit_types_treatment = "EXCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      units = "50"
    }
  }

  threshold_rules {
    threshold_percent = 0.5
  }
  threshold_rules {
    threshold_percent = 0.9
  }
  threshold_rules {
    threshold_percent = 1.0
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "FORECASTED_SPEND"
  }
}

locals {
  apis = [
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "spanner.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "artifactregistry.googleapis.com",
    "pubsub.googleapis.com",
    "cloudscheduler.googleapis.com",
    "workflows.googleapis.com",
    "secretmanager.googleapis.com",
    "aiplatform.googleapis.com",
    "iam.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "serviceusage.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each           = toset(local.apis)
  project            = google_project.twin.project_id
  service            = each.value
  disable_on_destroy = false
}
