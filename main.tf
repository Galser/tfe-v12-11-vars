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
    default="THIS SHOULD NOT BE IN OUTPUT"
}

resource "null_resource" "vars-test" {
  provisioner "local-exec" {
    command = "echo VARS : ${var.aws_region}"
  }
}
