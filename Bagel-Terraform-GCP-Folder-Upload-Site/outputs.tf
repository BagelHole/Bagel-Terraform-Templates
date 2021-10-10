# Website outputs

output "website_ip" {
  description = "IP address of the website, HTTP and HTTPS address"
  value       = google_compute_global_address.default.address
}
output "website_url_name" {
  description = "URL name of the website"
  value = var.website_domain_name
}

output "website_bucket_name" {
  description = "Name of the website bucket"
  value = google_compute_backend_bucket.static.name
}