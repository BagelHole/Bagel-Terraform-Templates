# Bagel Terraform Template
# This is for uploading a website's source code to GCP with HTTP(s) load balancing from a local folder
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

# Uploads files to bucket, this uses local gsutil command. Make sure it is downloaded on your device for this to work
resource "null_resource" "upload_folder_content" {
 triggers = {
   file_hashes = jsonencode({
   for fn in fileset(var.folder_path, "**") :
   fn => filesha256("${var.folder_path}/${fn}")
   })
  }

  provisioner "local-exec" {
    # The -m modifier allows for supported functions to run in parallel for faster performance.
    command = "gsutil -m cp -r ${var.folder_path}/* gs://${google_storage_bucket.website.name}/"  
  }

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

# Create a DNS record to point to registered Google Domain
resource "google_dns_managed_zone" "parent-zone" {
  provider    = google-beta
  name        = "${var.name}-site-dns"
  dns_name    = var.website_domain_name 
  description = "DNS record for ${var.website_domain_name}"
}

# This can cause a provider bug in creating the DNS records. If you run 'terraform apply' twice it will work.
resource "google_dns_record_set" "resource-recordset" {
  provider     = google-beta
  managed_zone = google_dns_managed_zone.parent-zone.name
  name         = "www.${var.website_domain_name}." //variable
  type         = "A"
  rrdatas      = ["10.0.0.1", "10.1.0.1",google_compute_global_address.default.address]
  ttl          = 3600
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