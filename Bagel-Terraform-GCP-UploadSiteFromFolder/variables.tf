# Required Parameters, users needs to input response.

variable "project" {
  description = "The project ID to host the site in."
  type        = string
  default = "your_project"
}

variable "credentialsFile" {
  # file comes from GCP -> IAM -> Service Accounts -> Actions -> Manage Keys
  description = "Following credential file needs to be in your local file with other terraform files."
  type = string
  default = "your_file.json"
} 

variable "website_domain_name" {
  description = "The name of the website and the Cloud Storage bucket to create (e.g. static.foo.com)."
  type        = string
  default = "yourdomain.com"
}

variable "name" {
  description = "Name for the load balancer forwarding rule and prefix for supporting resources."
  type        = string
  default = "your_name"
}

variable "url_map" {
  description = "A reference (self_link) to the url_map resource to use."
  type        = string
  default = "name-com-url-map"
}

variable "folder_path" {
  type        = string
  description = "Path to local folder that has website source code"
  default = "/Users/your_path/folder"
}

variable "website_location" {
  description = "Location of the bucket that will store the static website. Once a bucket has been created, its location can't be changed. See https://cloud.google.com/storage/docs/bucket-locations"
  type        = string
  default     = "US"
}

variable "website_storage_class" {
  description = "Storage class of the bucket that will store the static website"
  type        = string
  default     = "MULTI_REGIONAL"
}

# Optional Paremeters, have defaults but could be changed by user.
variable "custom_labels" {
  description = "A map of custom labels to apply to the resources. The key is the label name and the value is the label value."
  type        = map(string)
  default     = {}
}

variable "enable_versioning" {
  description = "Set to true to enable versioning. This means the website bucket will retain all old versions of all files. This is useful for backup purposes (e.g. you can rollback to an older version), but it may mean your bucket uses more storage."
  type        = bool
  default     = false
}

variable "index_page" {
  description = "Bucket's directory index"
  type        = string
  default     = "index.html"
}

variable "not_found_page" {
  description = "The custom object to return when a requested resource is not found"
  type        = string
  default     = "404.html"
}

variable "force_destroy_website" {
  description = "If set to true, this will force the delete of the website bucket when you run terraform destroy, even if there is still content in it. This is only meant for testing and should not be used in production."
  type        = bool
  default     = true
}

variable "enable_cors" {
  description = "Set to true if you want to enable CORS headers"
  type        = bool
  default     = false
}

variable "cors_origins" {
  description = "List of Origins eligible to receive CORS response headers. Note: '*' is permitted in the list of origins, and means 'any Origin'"
  type        = list(string)
  default     = []
}

variable "cors_methods" {
  description = "list of HTTP methods on which to include CORS response headers, (GET, OPTIONS, POST, etc). Note: '*' is permitted in the list of methods, and means 'any method'"
  type        = list(string)
  default     = []
}

variable "cors_extra_headers" {
  description = "List of HTTP headers other than the simple response headers to give permission for the user-agent to share across domains"
  type        = list(string)
  default     = []
}

variable "cors_max_age_seconds" {
  description = "The value, in seconds, to return in the Access-Control-Max-Age header used in preflight responses"
  type        = number
  default     = 600
}