# Google Cloud Platform Upload Site from GitHub

This Terraform code is for uploading a website's source code to a GCP bucket with HTTP(s) load balancing from a GitHub connected Repository. 
This site will be public and accessible at the IP address that is created. If you want to connect your domain to the IP that
must be done with your domain provider like [Google Domains](https://domains.google/).

## Cloud Build Trigger
This code is used by creating a trigger that will execute a cloud build YAML file that is inside your GitHub Repository. This YAML should have the gsutil commands needed to upload your website to the needed bucket. 

### Link to YAML file that deploys React.JS website to bucket
- [YAML CLoud Build for React.JS App]()

### Connect GitHub Repository to GCP
- In GCP go to Cloud Build, and then to Triggers. 
- Click on Manage Repositories and add your GitHub Repo 

## Terraform install
If this is your first time using Terraform you will need to install it. [Link to install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli).

## GCP Service Account
- Create a Terraform service account in your Google Cloud Platform project. 
- Create a key from that service account. 
#### Webmaster Central
- If you have a domain that is verified by Google go to [Webmaster Central](https://www.google.com/webmasters/verification/home).
- Add your Terraform service account as a verified owner to the domain. (this is needed for the website bucket that is created to have the same name as your domain) 

**note**: You could probably get around the Webmaster Central step if you do not want to name website bucket the same name as your domain. This might require some digging in the code. Not sure if this would work.

## Google Cloud APIs 
You will need to enable different APIs depending on what Terraform resources you are using. With none enabled you can run the terraform code, it will safely error out and tell you which APIs you need enabled. You can add these manually in GCP or it can be done programmatically through Terraform. 

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

variable "github_owner" {
  description = "The owner/organization of the GitHub Repo. For example in https://github.com/BagelHole/TobyCS-core-app the owner is BagelHole."
  type = string
  default = "your_github_owner"
}

variable "github_name_core_app" {
  description = "The name of the GitHub Repo. For example in https://github.com/BagelHole/TobyCS-core-app the name is TobyCS-core-app."
  type = string
  default = "your_github_repo_name"
}

variable "website_environment" {
  description = "The environment for the website. For Example: dev, prod, gamma, etc."
  type = string
  default = "dev"
}

variable "region_specific" {
  description = "Location of the bucket that will store the static website. Once a bucket has been created, its location can't be changed. See https://cloud.google.com/storage/docs/bucket-locations"
  type        = string
  default     = "us-west2"
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