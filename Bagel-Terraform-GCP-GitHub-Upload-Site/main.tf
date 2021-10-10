# Bagel Terraform Template
# This is for uploading a website's source code to GCP with HTTP(s) load balancing from a GitHub Repo Connection
# Make sure to change the varaibles in the variables.tf file 

terraform {
  required_version = ">= 0.12.26"
}

# Config the providor with credentials from Owner Service Account key.
provider "google-beta" { //don't need to use beta but I enjoy using the latest release when I code
  project = var.project
  # following credential file needs to be in your local file with other terraform files
  credentials = file(var.credentialsFile) // file comes from GCP -> IAM -> Service Accounts -> Actions -> Manage Keys
}

locals {
  # We have to use dashes instead of dots in the bucket name, because that bucket is not a website
  website_domain_name_dashed = replace(var.website_domain_name, ".", "-")
}

# Creating GCP Bootstrap allowing for GCP resources & permissions.
# This is by default commented out, but can be used to do other terraform actions if needed
/*
 module "bootstrap" {
  source  = "terraform-google-modules/bootstrap/google"
  version = "~> 2.1"

  org_id               = "<ORGANIZATION_ID>"
  billing_account      = "<BILLING_ACCOUNT_ID>"
  group_org_admins     = "gcp-organization-admins@example.com"
  group_billing_admins = "gcp-billing-admins@example.com"
  default_region       = "east"
 }*/

# Create a public IP adress with external scope
resource "google_compute_global_address" "default" {
  project      = var.project
  name         = "${var.name}-address"
  ip_version   = "IPV4"
  address_type = "EXTERNAL"
}

# Create the website bucket
resource "google_storage_bucket" "website" {
  provider = google-beta

  project = var.project

  // Make sure you give ownership to the service account of the domain in Google Webmaster or it wont create the bucket
  name          = var.website_domain_name 
  location      = var.website_location 
  storage_class = var.website_storage_class

  versioning {
    enabled = var.enable_versioning // Not used right now. Variable is False so it does nothing.
  }

  website {
    main_page_suffix = var.index_page
    not_found_page   = var.not_found_page
  }

  dynamic "cors" {
    for_each = var.enable_cors ? ["cors"] : []
    content {
      origin          = var.cors_origins
      method          = var.cors_methods
      response_header = var.cors_extra_headers
      max_age_seconds = var.cors_max_age_seconds
    }
  }

  force_destroy = var.force_destroy_website
/* // bucket encryption can be enabled here
  dynamic "encryption" {
    for_each = local.website_kms_keys
    content {
      default_kms_key_name = encryption.value
    }
  }
*/
  labels = var.custom_labels
  /* // Logging can be enabled here
  logging {
    log_bucket        = google_storage_bucket.access_logs.name
    log_object_prefix = var.access_log_prefix != "" ? var.access_log_prefix : local.website_domain_name_dashed
  }
  */
}

# Configure the buckets Access Control List (ACL) permissions 
resource "google_storage_bucket_acl" "public_rule" {
  bucket = google_storage_bucket.website.name
  role_entity = ["READER:allUsers"]
}

# Create the backend bucket that will point to the website storage bucket that houses the site source code
resource "google_compute_backend_bucket" "static" {
  provider = google-beta
  project  = var.project

  name        = "${local.website_domain_name_dashed}-bucket"
  bucket_name = google_storage_bucket.website.name
  enable_cdn  = false
}

# Cloud Build, Have to create the repository connections to GitHub in GCP before running this code
resource "google_cloudbuild_trigger" "core-app-env-trigger" {
  name = "core-app-${var.website_environment}-deploy"
  description = "Deploy of ${var.website_environment} core app"
  project = var.project
 
  github {
    owner = var.github_owner
    name = var.github_name_core_app 
  push {
    branch = var.github_push_branch 
    }

  } 
  
  substitutions = {
    _BUCKET_NAME = var.website_domain_name
    _ENVIRONMENT = var.website_environment 
    _REGION = var.region_specific
  }

  filename = "cloudbuild.yaml"

}

# Access Control List (ACL) permissions for website pages
resource "google_storage_default_object_acl" "default-object-acl" {
  bucket  = google_storage_bucket.website.name
  role_entity = ["READER:allUsers"]
}

# Create a SSL google cert to attach to load balancer to allow HTTPS
resource "google_compute_managed_ssl_certificate" "certificate" {
  name  = "${var.name}-cert"
  description = "SSL Certificate for ${var.website_domain_name}"
  project  = var.project
  provider = google-beta

  managed {
    domains = [var.website_domain_name] 
  }
}

# Create url map, forwarding rule, and proxy for HTTPS version of the site - Load Balacing
resource "google_compute_url_map" "com-url-map" { 
  project     = var.project
  name        = "${local.website_domain_name_dashed}-url-map"
  description = "URL map for ${var.website_domain_name}"

  default_service = google_compute_backend_bucket.static.self_link
}

resource "google_compute_global_forwarding_rule" "https" {
  provider   = google-beta
  project    = var.project
  name       = "${var.name}-https-rule"
  target     = google_compute_target_https_proxy.default.self_link
  ip_address = google_compute_global_address.default.address
  port_range = "443" // port for HTTPS

  labels = var.custom_labels
}

resource "google_compute_target_https_proxy" "default" {
  project = var.project
  name    = "${var.name}-https-proxy"
  url_map = google_compute_url_map.com-url-map.name

  ssl_certificates =[google_compute_managed_ssl_certificate.certificate.id]
}

# Create url map, forwarding rule, and proxy for HTTP version of the site - Load Balacing
# This load balancer has no backend but instead has a forwarding rule that just redirects HTTP to HTTPS for the site.
resource "google_compute_url_map" "http-redirect" {
  name        = "http-redirect-${var.name}"
  project     = var.project
  description = "http redirect to https for ${var.website_domain_name}"

  default_url_redirect {
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"  // 301 redirect
    strip_query            = false
    https_redirect         = true  // this is the magic
  }
}

resource "google_compute_global_forwarding_rule" "http-redirect" {
  name       = "http-redirect"
  project    = var.project
  target     = google_compute_target_http_proxy.http-redirect.self_link
  ip_address = google_compute_global_address.default.address
  port_range = "80" // port for HTTP
}

resource "google_compute_target_http_proxy" "http-redirect" {
  name    = "http-redirect-${var.name}"
  project = var.project
  url_map = google_compute_url_map.http-redirect.self_link
}

# This can be enabled if you want some health check stuff
/*
# Create backend service resource for https redirect and health check
resource "google_compute_backend_service" "home" {
  name        = "home"
  project     = var.project
  port_name   = "https"
  protocol    = "HTTPS"
  timeout_sec = 10

  health_checks = [google_compute_health_check.https-health-check.id]
  load_balancing_scheme = "INTERNAL_SELF_MANAGED"
}

resource "google_compute_health_check" "https-health-check" {
  name    = "https-health-check"
  project = var.project
  timeout_sec        = 1
  check_interval_sec = 1

  https_health_check {
    port = "443"
  }
}
*/