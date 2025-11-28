# Enterprise Lab

This lab is based on ideas of:

- [Automated Azure Arc](https://github.com/microsoft/azure_arc)
- [Lab Deployment in Azure](https://github.com/weeyin83/Lab-Deployment-in-Azure)

## Lab Use Cases Overview

This lab is designed to simulate a typical on-premises infrastructure,
providing a realistic environment with commonly used servers such as:

- Domain Controller – for identity and access management
- File Server – for centralized file storage and sharing
- SQL Database Server – for data-driven applications
- Web Servers – for hosting web-based services

By spinning up this lab, you can explore and experiment with several scenarios, including:

- Azure Arc Integration - Extend Azure management and services to on-prem servers by installing Azure Arc.
- Azure File Sync Configuration - Implement hybrid file services and synchronize data between on-prem and Azure for a production-like setup.
- Azure Migrate Assessment - Evaluate workloads for migration. Note: treat servers as physical machines since Hyper-V layer access is not available.
- Custom Use Cases - Test additional scenarios relevant to your environment or projects.

## Prerequisites

## Github Provisioning Pipeline

To configure Azure and GitHub Actions for automated deployments using a Service Principal (SP), follow these steps:

### 1. Create an Azure Service Principal

Run the following command in Azure CLI (replace `<NAME>` and `<SUBSCRIPTION_ID>`):

```sh
az ad sp create-for-rbac --name <NAME> --role contributor --scopes /subscriptions/<SUBSCRIPTION_ID>
```

This will output:
- `appId` (Client ID)
- `password` (Client Secret)
- `tenant` (Tenant ID)

### 2. Add Secrets to GitHub

In your GitHub repository, go to **Settings > Secrets and variables > Actions > New repository secret** and add:

- `AZURE_CREDENTIALS` = JSON output from the Service Principal creation (see below)
- `AZURE_SUBSCRIPTION_ID` = your Azure subscription ID
- `ADMIN_USERNAME` = administrator username for the lab VMs
- `ADMIN_PASSWORD` = administrator password for the lab VMs

**How to create `AZURE_CREDENTIALS`:**

After running the `az ad sp create-for-rbac` command, you need to transform the output into the format required by the Azure Login action.

The command outputs fields like `appId`, `password`, and `tenant`, but the action expects `clientId`, `clientSecret`, `tenantId`, and `subscriptionId`.

In GitHub, create a new secret named `AZURE_CREDENTIALS` with the following JSON structure:

```json
{
  "clientId": "<appId-from-command-output>",
  "clientSecret": "<password-from-command-output>",
  "tenantId": "<tenant-from-command-output>",
  "subscriptionId": "<your-subscription-id>"
}
```

This allows GitHub Actions to authenticate securely using the Service Principal.

### 3. Run GitHub Actions Workflow

This setup allows GitHub Actions to authenticate to Azure and deploy resources securely using the Service Principal.
You can now manually trigger the workflow from the GitHub Actions tab in your repository.
