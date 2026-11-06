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

locals {
  service_accounts = {
    "vdt-pipeline" = ["roles/bigquery.jobUser", "roles/bigquery.dataEditor", "roles/storage.objectAdmin", "roles/pubsub.publisher", "roles/spanner.databaseUser"]
    "vdt-sim"      = ["roles/bigquery.jobUser", "roles/bigquery.dataEditor", "roles/storage.objectAdmin"]
    "vdt-app"      = ["roles/bigquery.jobUser", "roles/bigquery.dataViewer", "roles/spanner.databaseReader"]
  }
  sa_roles = flatten([
    for sa, roles in local.service_accounts : [
      for role in roles : { sa = sa, role = role }
    ]
  ])
}

resource "google_service_account" "sa" {
  for_each     = local.service_accounts
  project      = google_project.twin.project_id
  account_id   = each.key
  display_name = each.key
  depends_on   = [google_project_service.apis]
}

resource "google_project_iam_member" "sa_roles" {
  for_each = { for b in local.sa_roles : "${b.sa}/${b.role}" => b }
  project  = google_project.twin.project_id
  role     = each.value.role
  member   = "serviceAccount:${google_service_account.sa[each.value.sa].email}"
}
