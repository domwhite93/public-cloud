

param(
    [bool]$WhatIfEnabled = $false
)

<#
.SYNOPSIS
    Automates the creation of Azure Privileged Identity Management (PIM) eligible role assignments 
    and updates role management policies based on predefined YAML configurations.

.DESCRIPTION
    This script performs the following tasks:
    - Loads custom cmdlets for PIM role assignment and module installation.
    - Installs required PowerShell modules:
        * PowerShell-Yaml (for parsing YAML configuration files)
        * Az.Accounts (for Azure authentication and token retrieval)
    - Connects to Azure (manual login if not running in a pipeline).
    - Retrieves an access token for management.azure.com.
    - Loads configuration data from YAML files:
        * roleAssignmentsByScope.yaml
        * pimSettings.yaml
        * defaultRoleManagementPolicy.yaml
    - Validates roles against a predefined list of allowed roles.
    - Applies PIM rules by merging default policies with custom settings.
    - Creates eligible role assignments and updates role management policies using REST API calls.

.NOTES
    - Requires Azure PowerShell modules and appropriate permissions.
    - Intended for use in Azure Landing Zones environments.
    - Authentication:
        * Manual: Device login prompt if no AzContext exists.
        * Automated: Pipeline handles authentication.

.LINK
    Microsoft Docs:
    - Manage eligible roles through PIM:
      https://learn.microsoft.com/en-us/rest/api/authorization/privileged-role-eligibility-rest-sample?view=rest-authorization-2020-10-01
    - Manage policies through PIM:
      https://learn.microsoft.com/en-us/rest/api/authorization/privileged-role-policy-rest-sample?view=rest-authorization-2020-10-01

#>

# Logging
$ErrorActionPreference = "Stop"
$Global:DefaultLogFile = "$PSScriptRoot\logs\Manage-AzureRBACPermissions.log"

# dot source cmdlets
. $PSScriptRoot/cmdlets/Set-AzurePIMEligibleRoleAssignment.ps1
. $PSScriptRoot/cmdlets/Install-ModuleHelper.ps1
. $PSScriptRoot/cmdlets/Add-Logline.ps1

# Modules
Install-ModuleHelper -module "PowerShell-yaml" # used for parsing yaml files
Install-Modulehelper -module "Az.Accounts" # used for Azure authentication and getting access token

## Main Script Logic
# Connect to Azure and get access token - only used for manual runs
# (if run via devops pipeline, the pipeline will take care of authentication)
If (!(Get-AzContext)) {
    Add-Logline -Message "Not logged in to Azure. Please log in." -Severity "Warning"
    Connect-AzAccount -UseDeviceAuthentication
}

# Get access token for management.azure.com
$token = (Get-AzAccessToken -ResourceUrl "https://management.azure.com").Token | ConvertFrom-SecureString -AsPlainText

# get roleAssignments / pimSettings / defaultRules / validRoles from yaml files
Try {
    $roleAssignmentsByScope = Get-Content -Path "$PSScriptRoot/roleAssignmentsByScope.yaml" -Raw | ConvertFrom-Yaml
    $pimSettings = Get-Content -Path "$PSScriptRoot/yaml/pimSettings.yaml" -Raw | ConvertFrom-Yaml 
    $defaultRules = Get-Content -Path "$PSScriptRoot/yaml/defaultRoleManagementPolicy.yaml" -Raw | ConvertFrom-Yaml
    $htValidRoles = Get-Content -Path "$PSScriptRoot/yaml/validRoles.yaml" -Raw | ConvertFrom-Yaml 
}
Catch {
    Add-Logline -Message "Failed to import file: $_" -Severity "Error"
    Exit
}
        

# Loop through the scopes and create PIM eligible role assignments
foreach ($scopeEntry in $roleAssignmentsByScope) {
    $scope = $scopeEntry.scope
    foreach ($assignment in $scopeEntry.assignments) {
        $role = $assignment.role
        $principalId = $assignment.principalId
        $pimSettingId = $assignment.pimSettingId

        # check if selected role is valid
        If (-not $htValidRoles.Keys -contains $role) {
            Add-Logline -Message "Role '$role' is not valid. Valid roles are: $($htValidRoles.Keys -join ', ')" -Severity "Error"
            Exit
        }
        $roleDefinitionId = $htValidRoles[$role]

        # get the assignments pimRules from template pimsettings
        $pimRules = ($pimsettings | Where-Object { $_.id -eq "$pimSettingId" }).rules

        # modify rules
        $objRules = $defaultRules.Clone()
        foreach ($rule in $objRules) {
            # find the matching default rule and update its properties
            foreach ($pimRule in $pimRules) {
                $ruleId = $pimRule.id
                $ruleToUpdate = $objRules | Where-Object { $_.id -eq $pimRule.id }
                if ($ruleToUpdate) {
                    foreach ($key in $pimRule.Keys) {
                        $ruleToUpdate.$key = $pimRule.$key
                    }
                }
            }
        }
        
        # call function to update role management policy and create role assignment
        try {
            If (!$WhatIfEnabled) {
                Set-AzurePIMEligibleRoleAssignment -scope $scope -roleDefinitionId $roleDefinitionId -principalId $principalId -roleManagementPolicyRules $objRules -token $token -ErrorAction Stop
            }
            Else {
                Add-Logline -Message "WhatIf: would create PIM eligible role assignment for role '$role' for principal $principalId at scope '$scope'." -Severity "Warning"  
            }
        }
        catch {
            Add-Logline -Message "Failed to create PIM eligible role assignment for role '$role' for principal $principalId at scope '$scope': $_" -Severity "Error"
        }
    }
}