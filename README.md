# Enterprise Lab

This lab is based on ideas of:

[Automated Azure Arc](https://github.com/microsoft/azure_arc)
[Lab Deployment in Azure](https://github.com/weeyin83/Lab-Deployment-in-Azure)

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
