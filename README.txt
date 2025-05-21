This terraform script deploys Azure Resources using Infrastructure as Code (IaC) to perform document analysis on PDFs.

Directions for deploying infrastructure: 

1. Log into Azure CLI:

    az login

2. Set Azure Subscription:

    az login               
    az account set --subscription "<SUBSCRIPTION-NAME-OR-GUID>"

3. Set Subscription ID: 

    export ARM_SUBSCRIPTION_ID="INSERT ID HERE"

4. Deploy Azure Resources via Terraform:

    terraform init   # only needed once per working directory
    terraform plan   # confirm no more errors
    terraform apply  # deploy when satisfied

Notes:

    - All of this infrastructure is deploy in Azure Region = West US 3