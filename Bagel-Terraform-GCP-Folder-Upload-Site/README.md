# Google Cloud Platform Upload Site from Folder

This Terraform code is for uploading a website's source code to a GCP bucket with HTTP(s) load balancing from a local folder. 
This site will be public and accessible at the IP address that is created. If you want to connect your domain to the IP that
must be done with your domain provider like [Google Domains](https://domains.google/).

## Terraform install
If this is your first time using Terraform you will need to install it. [Link to install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli).

## gsutil install
gsutil is used in this terraform code to upload files from your local machine to the cloud storage. It must be installed to correctly work.
The following link can help with install of gsutil: 
[Install gsutil](https://cloud.google.com/storage/docs/gsutil_install#macos)

## GCP Service Account
- Create a Terraform service account in your Google Cloud Platform project. 
- Create a key from that service account. 
#### Webmaster Central
- If you have a domain that is verified by Google go to [Webmaster Central](https://www.google.com/webmasters/verification/home).
- Add your Terraform service account as a verified owner to the domain. (this is needed for the website bucket that is created to have the same name as your domain) 

**note**: You could probably get around the Webmaster Central step if you do not want to name website bucket the same name as your domain. This might require some digging in the code. Not sure if this would work.

## Google Cloud APIs 
You will need to enable different APIs depending on what Terraform resources you are using. With no APIs enabled you can run the terraform code, it will safely error out and tell you which APIs you need enabled. You can add these manually in GCP or it can be done programmatically through Terraform. 
- [Terraform for Enabling API](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service)

### APIs needed for this code:
- Compute Engine
- Cloud Build
- Cloud Resource Manager
- Cloud Storage

## Before first run
- Run command below in terminal to provide authentication credentials to your application code by setting the environment variable.

```bash
 export GOOGLE_APPLICATION_CREDENTIALS="your_file.json" 
```

- Run command below in terminal to authenticate gsutil:

```bash
 gsutil config
```


## Usage
Make sure to change the needed variables in the variables.tf file. 

```bash
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

variable "folder_path" {
  type        = string
  description = "Path to local folder that has website source code"
  default = "/Users/your_path/folder"
}
````
Run the below commands in terminal from your source Terraform folder:
````bash
terraform init
terraform plan
terraform apply
````
Terraform plan is less needed because 'terraform apply' shows a plan before you apply.


## DNS & SSL Cert
The Google Created SSL Cert for HTTPS can take a bit of time to create (15min-1hour)

The DNS records that need to be set in your domain provider can take some time to populate (15min-24hours)


## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License
[MIT](https://choosealicense.com/licenses/mit/)