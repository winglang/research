#!/bin/sh
export TF_BACKEND_BUCKET="eladb-tfstate"
export TF_BACKEND_BUCKET_REGION="eu-west-2"
wing compile -p ./tf-s3-backend.js -t tf-aws main.w
cd target/main.tfaws
terraform init
terraform apply