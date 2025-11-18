# Azure RBAC Roles - according to ALZ Architecture

## Roles for Users
There are four roles which can be assigned to Users based on the recommendations from the Azure Landing Zone Conceptual Architecture. The role definitions are defined in [Identity and access management](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/enterprise-scale/identity-and-access-management) recommendations.

**Roles Explanation**
- Subscription Owner: Full control of workload subscription lifecycle.
- Application Owners: Deploy and manage workloads within guardrails.
- Network Management: Centralized control of networking and firewall policies.
- Security Operations: Security posture, compliance, and monitoring across all subscriptions.

::: mermaid
flowchart TD
    A["Management Group: Landing Zones"] --> B["Subscription Owner"]
    A --> C["Application Owners (DevOps/AppOps)"]
    A --> D["Network Management (NetOps)"]
    A --> E["Security Operations (SecOps)"]

    B -->|Full subscription control| F[Workload Subscription]
    C -->|Manage workloads| F
    D -->|Manage connectivity| G[Connectivity Subscription]
    E -->|Manage security posture| H[All Subscriptions]
::: 


**Comparism Table**

| **Role**                                     | **Scope**                 | **Key Permissions**                                                             | **Use Cases**                                                                                 |
|----------------------------------------------|---------------------------|---------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------|
| **[alz] Subscription Owner**                 | Workload Subscription     | - Full CRUD on resources<br>- Assign RBAC<br>- Manage costs                     | - Lifecycle management of workload subscriptions<br>- Rarely used for daily ops (use PIM)     |
| **[alz] Application Owners (DevOps/AppOps)** | Workload Subscription     | - Deploy workloads via IaC<br>- Manage app resources<br>- Configure monitoring  | - DevOps teams deploying AKS, VMs, App Services<br>- Operate within policy guardrails         |
| **[alz] Network Management (NetOps)**        | Connectivity Subscription | - Manage VNets, peering, gateways<br>- Configure Firewall & DNS                 | - Central networking team managing hub-spoke architecture<br>- Firewall policy & connectivity |
| **[alz] Security Operations (SecOps)**       | All Subscriptions         | - Manage Defender for Cloud<br>- Configure security policies<br>- Access alerts | - SOC team enforcing compliance<br>- Threat detection and vulnerability management            |


# Script
## initial requirements:
- assignments with modify-rights should always be PIM-eligible, never direct assigned
- the eligible assignments should be allowed to set "permanently eligible" (Tick box at "Allow permanent eligible assignment" in the PIM policy)
- the activation always needs MFA (Tick box at "Require Azure Multi-Factor Authentication on active assignment" in the PIM policy)
- for certain assignments we need approval (require approval and add approvers in the PIM policy)
- the roles should always be activated at the lowest possible level (educate azure users)

## Content
| file/folder | description |
| --- | --- |
| Manage-AzureRBACPermissions.ps1 | Main script |
| roleAssignmentsByScope.yaml | the config file containing the assignments for each scope, including the selected pim policy setting |
| cmdlets/\*.\* | contains a logging and module-installation cmdlet, and the main Set-AzurePIMEligibleRoleAssignment.ps1 cmdlet |
| yaml/defaultRoleManagementPolicy.yaml | a yaml representation of a default role management policy of an unmodified azure role |
| yaml/pimSettings.yaml | a yaml representation of your own pim-settings, which are then referenced in roleAssignmentsByScope.yaml |
| logs/\*.\* | log folder |

## Get Started
- edit pimSettings.yaml according to your organizations needs (view available rules in defaultRoleManagementPolicy.yaml)
- edit roleAssignmentsByScope.yaml to your organizations needs
- elevate your own account to owner at the right scope (you need owner permissions to set new permissions for other users/groups)
- run the script

## Disclaimer
- use at your own risk. always test throughly before running in production
- this script is far from perfect. input/recommendations are welcome.

