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

## Analysis

# Reproducing 

## Terrraform CLI v0.12.11 and TFE v0.12.11
- Create and organozation and workspace in TFE
- DEfine variable with name `"aws_region"` and value `"us-east-1"` (actually any value and name, this just for the ease of reference later in the example code), not senstive, not HCL 
- Now, locally, with the one and only Terraform file [main.tf] (main.tf) with the contents as below :
```
terraform {
  backend "remote" {
    organization = "galser-free"

    workspaces {
      name = "vars-test"
    }
  }
}

variable "aws_region" { 
# With next line commented, configutation fails in Terraform v0.12.11    
#    default="THIS SHOULD NOT BE IN OUTPUT"
}

resource "null_resource" "vars-test" {
  provisioner "local-exec" {
    command = "echo VARS : ${var.aws_region}"
  }
}
```
- init Terraform :
```
terraform init
```
- Check version : 
```
terraform -version
Terraform v0.12.11
+ provider.null v2.1.2
```
- Ensure that there is not version override in TFE settings for the selected workspace, if there is any, set it to v 0.12.11
- Providers version or providers presence - not important
- Try to apply :
```bash
Error: No value for required variable

  on main.tf line 11:
  11: variable "aws_region" { 

The root module input variable "aws_region" is not set, and has no default
value. Use a -var or -var-file command line argument to provide a value for
this variable.
```
It fails immediately. **But, traffic dump is showing that there are request going to both directions.**
Here is the same output in TRACE mode : 
```bash
TF_LOG=TRACE terraform apply
2019/10/18 15:17:50 [INFO] Terraform version: 0.12.11  
2019/10/18 15:17:50 [INFO] Go runtime version: go1.12.9
2019/10/18 15:17:50 [INFO] CLI args: []string{"/usr/local/bin/terraform", "apply"}
2019/10/18 15:17:50 [DEBUG] Attempting to open CLI config file: /Users....terraformrc
2019/10/18 15:17:50 Loading CLI configuration from /Users....terraformrc
2019/10/18 15:17:50 [INFO] CLI command args: []string{"apply"}
2019/10/18 15:17:50 [TRACE] Meta.Backend: built configuration for "remote" backend with hash value 1504337154
2019/10/18 15:17:50 [TRACE] Preserving existing state lineage "58e8f339-733d-e506-8f03-c595a8c51a56"
2019/10/18 15:17:50 [TRACE] Preserving existing state lineage "58e8f339-733d-e506-8f03-c595a8c51a56"
2019/10/18 15:17:50 [TRACE] Meta.Backend: working directory was previously initialized for "remote" backend
2019/10/18 15:17:50 [TRACE] Meta.Backend: using already-initialized, unchanged "remote" backend configuration
2019/10/18 15:17:50 [DEBUG] Service discovery for app.terraform.io at https://app.terraform.io/.well-known/terraform.json
2019/10/18 15:17:50 [TRACE] HTTP client GET request to https://app.terraform.io/.well-known/terraform.json
2019/10/18 15:17:51 [DEBUG] Retrieve version constraints for service tfe.v2.1 and product terraform
2019/10/18 15:17:51 [TRACE] HTTP client GET request to https://checkpoint-api.hashicorp.com/v1/versions/tfe.v2.1?product=terraform
2019/10/18 15:17:52 [TRACE] Meta.Backend: instantiated backend of type *remote.Remote
2019/10/18 15:17:52 [DEBUG] checking for provider in "."
2019/10/18 15:17:52 [DEBUG] checking for provider in "/usr/local/bin"
2019/10/18 15:17:52 [DEBUG] checking for provider in ".terraform/plugins/darwin_amd64"
2019/10/18 15:17:52 [DEBUG] found provider "terraform-provider-null_v2.1.2_x4"
2019/10/18 15:17:52 [DEBUG] found valid plugin: "null", "2.1.2", "/Users.../tfe-v12-11-vars/.terraform/plugins/darwin_amd64/terraform-provider-null_v2.1.2_x4"
2019/10/18 15:17:52 [DEBUG] checking for provisioner in "."
2019/10/18 15:17:52 [DEBUG] checking for provisioner in "/usr/local/bin"
2019/10/18 15:17:52 [DEBUG] checking for provisioner in ".terraform/plugins/darwin_amd64"
2019/10/18 15:17:52 [TRACE] Meta.Backend: backend *remote.Remote supports operations
2019/10/18 15:17:52 [INFO] backend/remote: starting Apply operation

Error: No value for required variable

  on main.tf line 11:
  11: variable "aws_region" { 

The root module input variable "aws_region" is not set, and has no default
value. Use a -var or -var-file command line argument to provide a value for
this variable.
```

## Terrraform CLI v0.12.11 and TFE v0.12.10
- Go the TFE settings, for the workspace in example  ->  General Settings , and change Terraform Version to **0.12.10**. Press [Save settings]
- Try from local shell to apply TF configuration : 
```bash
TF_LOG=TRACE terraform apply
2019/10/18 15:27:16 [INFO] Terraform version: 0.12.11  
2019/10/18 15:27:16 [INFO] Go runtime version: go1.12.9
2019/10/18 15:27:16 [INFO] CLI args: []string{"/usr/local/bin/terraform", "apply"}
2019/10/18 15:27:16 [DEBUG] Attempting to open CLI config file: /Users/andrii/.terraformrc
2019/10/18 15:27:16 Loading CLI configuration from /Users/andrii/.terraformrc
2019/10/18 15:27:16 [INFO] CLI command args: []string{"apply"}
2019/10/18 15:27:16 [TRACE] Meta.Backend: built configuration for "remote" backend with hash value 1504337154
2019/10/18 15:27:16 [TRACE] Preserving existing state lineage "58e8f339-733d-e506-8f03-c595a8c51a56"
2019/10/18 15:27:16 [TRACE] Preserving existing state lineage "58e8f339-733d-e506-8f03-c595a8c51a56"
2019/10/18 15:27:16 [TRACE] Meta.Backend: working directory was previously initialized for "remote" backend
2019/10/18 15:27:16 [TRACE] Meta.Backend: using already-initialized, unchanged "remote" backend configuration
2019/10/18 15:27:16 [DEBUG] Service discovery for app.terraform.io at https://app.terraform.io/.well-known/terraform.json
2019/10/18 15:27:16 [TRACE] HTTP client GET request to https://app.terraform.io/.well-known/terraform.json
2019/10/18 15:27:16 [DEBUG] Retrieve version constraints for service tfe.v2.1 and product terraform
2019/10/18 15:27:16 [TRACE] HTTP client GET request to https://checkpoint-api.hashicorp.com/v1/versions/tfe.v2.1?product=terraform
2019/10/18 15:27:18 [TRACE] Meta.Backend: instantiated backend of type *remote.Remote
2019/10/18 15:27:18 [DEBUG] checking for provider in "."
2019/10/18 15:27:18 [DEBUG] checking for provider in "/usr/local/bin"
2019/10/18 15:27:18 [DEBUG] checking for provider in ".terraform/plugins/darwin_amd64"
2019/10/18 15:27:18 [DEBUG] found provider "terraform-provider-null_v2.1.2_x4"
2019/10/18 15:27:18 [DEBUG] found valid plugin: "null", "2.1.2", "/Users/andrii/labs/skills/tfe-v12-11-vars/.terraform/plugins/darwin_amd64/terraform-provider-null_v2.1.2_x4"
2019/10/18 15:27:18 [DEBUG] checking for provisioner in "."
2019/10/18 15:27:18 [DEBUG] checking for provisioner in "/usr/local/bin"
2019/10/18 15:27:18 [DEBUG] checking for provisioner in ".terraform/plugins/darwin_amd64"
2019/10/18 15:27:18 [TRACE] Meta.Backend: backend *remote.Remote supports operations
2019/10/18 15:27:18 [INFO] backend/remote: starting Apply operation

Error: No value for required variable

  on main.tf line 11:
  11: variable "aws_region" { 

The root module input variable "aws_region" is not set, and has no default
value. Use a -var or -var-file command line argument to provide a value for
this variable.
```
Same error

## Terrraform CLI v0.12.10 and TFE v0.12.10
- Now change your local TE CLI version to v0.12.10
- You TFE version should be also v0.12.10
- Use same code, run apply : 
```
TF_LOG=TRACE terraform apply           
2019/10/18 15:44:14 [INFO] Terraform version: 0.12.10  
2019/10/18 15:44:14 [INFO] Go runtime version: go1.12.9
2019/10/18 15:44:14 [INFO] CLI args: []string{"/usr/local/bin/terraform", "apply"}
2019/10/18 15:44:14 [DEBUG] Attempting to open CLI config file: /Users/andrii/.terraformrc
2019/10/18 15:44:14 Loading CLI configuration from /Users/andrii/.terraformrc
2019/10/18 15:44:14 [INFO] CLI command args: []string{"apply"}
2019/10/18 15:44:14 [TRACE] Meta.Backend: built configuration for "remote" backend with hash value 1504337154
2019/10/18 15:44:14 [TRACE] Preserving existing state lineage "58e8f339-733d-e506-8f03-c595a8c51a56"
2019/10/18 15:44:14 [TRACE] Preserving existing state lineage "58e8f339-733d-e506-8f03-c595a8c51a56"
2019/10/18 15:44:14 [TRACE] Meta.Backend: working directory was previously initialized for "remote" backend
2019/10/18 15:44:14 [TRACE] Meta.Backend: using already-initialized, unchanged "remote" backend configuration
2019/10/18 15:44:14 [DEBUG] Service discovery for app.terraform.io at https://app.terraform.io/.well-known/terraform.json
2019/10/18 15:44:14 [TRACE] HTTP client GET request to https://app.terraform.io/.well-known/terraform.json
2019/10/18 15:44:16 [DEBUG] Retrieve version constraints for service tfe.v2.1 and product terraform
2019/10/18 15:44:16 [TRACE] HTTP client GET request to https://checkpoint-api.hashicorp.com/v1/versions/tfe.v2.1?product=terraform
2019/10/18 15:44:17 [TRACE] Meta.Backend: instantiated backend of type *remote.Remote
2019/10/18 15:44:17 [DEBUG] checking for provider in "."
2019/10/18 15:44:17 [DEBUG] checking for provider in "/usr/local/bin"
2019/10/18 15:44:17 [DEBUG] checking for provider in ".terraform/plugins/darwin_amd64"
2019/10/18 15:44:17 [DEBUG] found provider "terraform-provider-null_v2.1.2_x4"
2019/10/18 15:44:17 [DEBUG] found valid plugin: "null", "2.1.2", "/Users/andrii/labs/skills/tfe-v12-11-vars/.terraform/plugins/darwin_amd64/terraform-provider-null_v2.1.2_x4"
2019/10/18 15:44:17 [DEBUG] checking for provisioner in "."
2019/10/18 15:44:17 [DEBUG] checking for provisioner in "/usr/local/bin"
2019/10/18 15:44:17 [DEBUG] checking for provisioner in ".terraform/plugins/darwin_amd64"
2019/10/18 15:44:17 [TRACE] Meta.Backend: backend *remote.Remote supports operations
2019/10/18 15:44:17 [INFO] backend/remote: starting Apply operation
Running apply in the remote backend. Output will stream here. Pressing Ctrl-C
will cancel the remote apply if it's still pending. If the apply started it
will stop streaming the logs, but will not stop the apply running remotely.

Preparing the remote apply...

To view this run in a browser, visit:
https://app.terraform.io/app/galser-free/vars-test/runs/run-PEW2SbMeWhWkCqUY

Waiting for the plan to start...

Terraform v0.12.10
Configuring remote state backend...
Initializing Terraform configuration...
2019/10/18 13:44:28 [DEBUG] Using modified User-Agent: Terraform/0.12.10 TFC/f28c3b610f
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.


------------------------------------------------------------------------

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # null_resource.vars-test will be created
  + resource "null_resource" "vars-test" {
      + id = (known after apply)
    }

Plan: 1 to add, 0 to change, 0 to destroy.
2019/10/18 15:44:37 [DEBUG] command: asking for input: "\nDo you want to perform these actions in workspace \"vars-test\"?"

Do you want to perform these actions in workspace "vars-test"?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

null_resource.vars-test: Creating...
null_resource.vars-test: Provisioning with 'local-exec'...
null_resource.vars-test (local-exec): Executing: ["/bin/sh" "-c" "echo VARS : us-east-1"]
null_resource.vars-test (local-exec): VARS : us-east-1
null_resource.vars-test: Creation complete after 0s [id=3064167799935428901]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```
Success


## POSSIBLE WORKAROUND : With ANY default value for the variable set
- Return back both Terraform CLI and TFE Workspace version to v0.12.11
- Change main code Terraform file [main.tf] (main.tf) so the variable definition looks like this : 
```terraform
variable "aws_region" { 
# With next line commented, configutation fails in Terraform v0.12.11    
    default="THIS SHOULD NOT BE IN OUTPUT"
}
```
- Taint resource
- Run Terraform apply :
```bash
TF_LOG=TRACE terraform apply
2019/10/18 15:47:28 [INFO] Terraform version: 0.12.11  
2019/10/18 15:47:28 [INFO] Go runtime version: go1.12.9
2019/10/18 15:47:28 [INFO] CLI args: []string{"/usr/local/bin/terraform", "apply"}
2019/10/18 15:47:28 [DEBUG] Attempting to open CLI config file: /Users/andrii/.terraformrc
2019/10/18 15:47:28 Loading CLI configuration from /Users/andrii/.terraformrc
2019/10/18 15:47:28 [INFO] CLI command args: []string{"apply"}
2019/10/18 15:47:28 [TRACE] Meta.Backend: built configuration for "remote" backend with hash value 1504337154
2019/10/18 15:47:28 [TRACE] Preserving existing state lineage "58e8f339-733d-e506-8f03-c595a8c51a56"
2019/10/18 15:47:28 [TRACE] Preserving existing state lineage "58e8f339-733d-e506-8f03-c595a8c51a56"
2019/10/18 15:47:28 [TRACE] Meta.Backend: working directory was previously initialized for "remote" backend
2019/10/18 15:47:28 [TRACE] Meta.Backend: using already-initialized, unchanged "remote" backend configuration
2019/10/18 15:47:28 [DEBUG] Service discovery for app.terraform.io at https://app.terraform.io/.well-known/terraform.json
2019/10/18 15:47:28 [TRACE] HTTP client GET request to https://app.terraform.io/.well-known/terraform.json
2019/10/18 15:47:28 [DEBUG] Retrieve version constraints for service tfe.v2.1 and product terraform
2019/10/18 15:47:28 [TRACE] HTTP client GET request to https://checkpoint-api.hashicorp.com/v1/versions/tfe.v2.1?product=terraform
2019/10/18 15:47:29 [TRACE] Meta.Backend: instantiated backend of type *remote.Remote
2019/10/18 15:47:29 [DEBUG] checking for provider in "."
2019/10/18 15:47:29 [DEBUG] checking for provider in "/usr/local/bin"
2019/10/18 15:47:29 [DEBUG] checking for provider in ".terraform/plugins/darwin_amd64"
2019/10/18 15:47:29 [DEBUG] found provider "terraform-provider-null_v2.1.2_x4"
2019/10/18 15:47:29 [DEBUG] found valid plugin: "null", "2.1.2", "/Users/andrii/labs/skills/tfe-v12-11-vars/.terraform/plugins/darwin_amd64/terraform-provider-null_v2.1.2_x4"
2019/10/18 15:47:29 [DEBUG] checking for provisioner in "."
2019/10/18 15:47:29 [DEBUG] checking for provisioner in "/usr/local/bin"
2019/10/18 15:47:29 [DEBUG] checking for provisioner in ".terraform/plugins/darwin_amd64"
2019/10/18 15:47:29 [TRACE] Meta.Backend: backend *remote.Remote supports operations
2019/10/18 15:47:29 [INFO] backend/remote: starting Apply operation
Running apply in the remote backend. Output will stream here. Pressing Ctrl-C
will cancel the remote apply if it's still pending. If the apply started it
will stop streaming the logs, but will not stop the apply running remotely.

Preparing the remote apply...

To view this run in a browser, visit:
https://app.terraform.io/app/galser-free/vars-test/runs/run-xwpVuiiDmTnpiQEt

Waiting for the plan to start...

Terraform v0.12.11
Configuring remote state backend...
Initializing Terraform configuration...
2019/10/18 13:47:43 [DEBUG] Using modified User-Agent: Terraform/0.12.11 TFC/f28c3b610f
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.

null_resource.vars-test: Refreshing state... [id=3064167799935428901]

------------------------------------------------------------------------

No changes. Infrastructure is up-to-date.

This means that Terraform did not detect any differences between your
configuration and real physical resources that exist. As a result, no
actions need to be performed.
```
OKay. logical. Let's taint resource and run once more  : 
```bash
terraform taint null_resource.vars-test
Acquiring state lock. This may take a few moments...
Resource instance null_resource.vars-test has been marked as tainted.

 TF_LOG=TRACE terraform apply           
2019/10/18 15:49:05 [INFO] Terraform version: 0.12.11  
2019/10/18 15:49:05 [INFO] Go runtime version: go1.12.9
2019/10/18 15:49:05 [INFO] CLI args: []string{"/usr/local/bin/terraform", "apply"}
2019/10/18 15:49:05 [DEBUG] Attempting to open CLI config file: /Users/andrii/.terraformrc
2019/10/18 15:49:05 Loading CLI configuration from /Users/andrii/.terraformrc
2019/10/18 15:49:05 [INFO] CLI command args: []string{"apply"}
2019/10/18 15:49:05 [TRACE] Meta.Backend: built configuration for "remote" backend with hash value 1504337154
2019/10/18 15:49:05 [TRACE] Preserving existing state lineage "58e8f339-733d-e506-8f03-c595a8c51a56"
2019/10/18 15:49:05 [TRACE] Preserving existing state lineage "58e8f339-733d-e506-8f03-c595a8c51a56"
2019/10/18 15:49:05 [TRACE] Meta.Backend: working directory was previously initialized for "remote" backend
2019/10/18 15:49:05 [TRACE] Meta.Backend: using already-initialized, unchanged "remote" backend configuration
2019/10/18 15:49:05 [DEBUG] Service discovery for app.terraform.io at https://app.terraform.io/.well-known/terraform.json
2019/10/18 15:49:05 [TRACE] HTTP client GET request to https://app.terraform.io/.well-known/terraform.json
2019/10/18 15:49:06 [DEBUG] Retrieve version constraints for service tfe.v2.1 and product terraform
2019/10/18 15:49:06 [TRACE] HTTP client GET request to https://checkpoint-api.hashicorp.com/v1/versions/tfe.v2.1?product=terraform
2019/10/18 15:49:08 [TRACE] Meta.Backend: instantiated backend of type *remote.Remote
2019/10/18 15:49:08 [DEBUG] checking for provider in "."
2019/10/18 15:49:08 [DEBUG] checking for provider in "/usr/local/bin"
2019/10/18 15:49:08 [DEBUG] checking for provider in ".terraform/plugins/darwin_amd64"
2019/10/18 15:49:08 [DEBUG] found provider "terraform-provider-null_v2.1.2_x4"
2019/10/18 15:49:08 [DEBUG] found valid plugin: "null", "2.1.2", "/Users/andrii/labs/skills/tfe-v12-11-vars/.terraform/plugins/darwin_amd64/terraform-provider-null_v2.1.2_x4"
2019/10/18 15:49:08 [DEBUG] checking for provisioner in "."
2019/10/18 15:49:08 [DEBUG] checking for provisioner in "/usr/local/bin"
2019/10/18 15:49:08 [DEBUG] checking for provisioner in ".terraform/plugins/darwin_amd64"
2019/10/18 15:49:08 [TRACE] Meta.Backend: backend *remote.Remote supports operations
2019/10/18 15:49:09 [INFO] backend/remote: starting Apply operation
Running apply in the remote backend. Output will stream here. Pressing Ctrl-C
will cancel the remote apply if it's still pending. If the apply started it
will stop streaming the logs, but will not stop the apply running remotely.

Preparing the remote apply...

To view this run in a browser, visit:
https://app.terraform.io/app/galser-free/vars-test/runs/run-v5457LBnvGwGzRpE

Waiting for the plan to start...

Terraform v0.12.11
Configuring remote state backend...
Initializing Terraform configuration...
2019/10/18 13:49:21 [DEBUG] Using modified User-Agent: Terraform/0.12.11 TFC/f28c3b610f
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.

null_resource.vars-test: Refreshing state... [id=3064167799935428901]

------------------------------------------------------------------------

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
-/+ destroy and then create replacement

Terraform will perform the following actions:

  # null_resource.vars-test is tainted, so must be replaced
-/+ resource "null_resource" "vars-test" {
      ~ id = "3064167799935428901" -> (known after apply)
    }

Plan: 1 to add, 0 to change, 1 to destroy.

2019/10/18 15:49:32 [DEBUG] command: asking for input: "\nDo you want to perform these actions in workspace \"vars-test\"?"
Do you want to perform these actions in workspace "vars-test"?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

null_resource.vars-test: Destroying... [id=3064167799935428901]
null_resource.vars-test: Destruction complete after 0s
null_resource.vars-test: Creating...
null_resource.vars-test: Provisioning with 'local-exec'...
null_resource.vars-test (local-exec): Executing: ["/bin/sh" "-c" "echo VARS : us-east-1"]
null_resource.vars-test (local-exec): VARS : us-east-1
null_resource.vars-test: Creation complete after 0s [id=4298298393982500476]

Apply complete! Resources: 1 added, 0 changed, 1 destroyed.
```
Again. success, please pay attention that the actual value of the variable is CORRECT~ -taken from TFE, not from the local default value : 
`null_resource.vars-test (local-exec):*`VARS : **us-east-1**

*Looks like a bug. *
