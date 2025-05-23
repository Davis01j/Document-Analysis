This terraform script deploys Azure Resources using Infrastructure as Code (IaC) to perform document analysis on PDFs.

Directions for deploying infrastructure: 

1. Log into Azure CLI:
    az login

2. Set Azure Subscription:
    az login 
    az account show              
    az account set --subscription "<SUBSCRIPTION-NAME-OR-GUID>"

3. Set Subscription ID: 
    export ARM_SUBSCRIPTION_ID="INSERT ID HERE"

4. Deploy Azure Resources via Terraform:
    terraform init   
    terraform plan   
    terraform apply  # deploy Azure infrastructure

5. Set Environment Variables:
    set -a && source /PATH/TO/YOUR/terraform.env && set +a    #Update and save terraform.env file before running and deploying Azure Infrastructure


Additional Commands:

1. View Azure Subscriptions:
    az account list --output table

2. Set Azure Subscription:
    az account set --subscription "<subscription name or id>"

3. Verify Azure Subscription:
    az account show --output table

4. List Resource Groups in selected Subscription:
    az group list --output table

5. List Resources in a Specific Resource Group:
    az resource list --resource-group "<resource-group-name>" --output table

6. See all Resources Accross Subscriptions:
    az resource list --output table

7. Delete Resource Group:
    az group delete --name "<resource-group>" --yes --no-wait

Deploy Azure Infrastructure:

1. Create Resource Group:
    az group create \
        --name dataproject-rg \
        --location westus3

2. Create a Storage Account:
    az storage account create \
         --name dataprojectfuncsa \
         --resource-group dataproject-rg \
         --location westus3 \
         --sku Standard_LRS



Notes:

    - All of this infrastructure is deploy in Azure Region = West US 3