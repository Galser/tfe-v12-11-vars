# tfe-v12-11-vars
Possible bug in TFE 12.11 with variables values defined only in TFE, not in code or external


# Initial input

This came as possible bug :  https://github.com/hashicorp/terraform/issues/23115

I'm trying to run terraform plan on a remote backend (terraform cloud) with 0.12.11 however it always says variable not set. I suspect this is related to [#21659](https://github.com/hashicorp/terraform/issues/21659)

## Terraform Version
```
Terraform v0.12.11
+ provider.aws v2.33.0
```

## TF Config 

```terraform
terraform {
  backend "remote" {
    organization = "fave"

    workspaces {
      prefix = "data-pipeline_staging_main_v1_"
    }
  }
}

provider "aws" {
  version = "~> 2.0"

  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key

  assume_role {
    role_arn = var.aws_role_arn
  }
}

resource "aws_s3_bucket" "target" {
  bucket_prefix = "my-bucket"
  force_destroy = true
}
```

Output : 
```bash
Error: No value for required variable

  on variables.tf line 1:
   1: variable "spotinst_token" {

The root module input variable "spotinst_token" is not set, and has no default
value. Use a -var or -var-file command line argument to provide a value for
this variable.


Error: No value for required variable

  on variables.tf line 5:
   5: variable "spotinst_account" {

The root module input variable "spotinst_account" is not set, and has no
default value. Use a -var or -var-file command line argument to provide a
value for this variable.
...
```

## Expected Behavior
Remote terraform plan should be run in the cloud where all variables are already set

## Actual Behavior
Terraform plan reports missing variables

## Steps to Reproduce
- terraform init with backend set to terraform cloud
-  terraform plan
```

## Run logs and tests
