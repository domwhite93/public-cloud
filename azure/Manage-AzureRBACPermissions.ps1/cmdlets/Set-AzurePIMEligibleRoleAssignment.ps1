function Set-AzurePIMEligibleRoleAssignment {
    param (
        [string]$scope,
        [string]$roleDefinitionId,
        [string]$principalId,
        [object]$roleManagementPolicyRules,
        [string]$token
    )
    
    # build headers to use in REST API calls
    $headers = @{
        "Authorization" = "Bearer $token"
        "Content-Type"  = "application/json" 
    }

    ## edit the existing Role Management Policy at the defined scope for the role
    # (this way, we allow for example eligible assignments to be created permanently)
    # get the role management policy for that roleDefinitionId
    $uri = "https://management.azure.com/$($scope)/providers/Microsoft.Authorization/roleManagementPolicies?api-version=2020-10-01&`$filter=roleDefinitionId eq '$($scope)/providers/Microsoft.Authorization/roleDefinitions/$($roleDefinitionId)'"
    
    try {
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
        $roleManagementPolicyName = $response.value.Name
    }
    catch {
        Add-Logline -Message "Failed to get role management policy: $_" -Severity "Error"
        return
    }

    # build payload
    $apiBody = "{`"properties`": { `"rules`": $($roleManagementPolicyRules | ConvertTo-Json -Depth 10) }}"

    # update policy
    $uri = "https://management.azure.com/$($scope)/providers/Microsoft.Authorization/roleManagementPolicies/$($roleManagementPolicyName)?api-version=2020-10-01"
    
    try {
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Patch -Body $apiBody -ErrorAction Stop
    }
    catch {
        Add-Logline -Message "Failed to update role management policy: $_" -Severity "Error"
        return
    }

    # create eligible assignment schedule (remove would be with requestType = "AdminRemove")
    $roleEligibilityScheduleRequestName = [guid]::NewGuid().ToString()
    $body = @{
        properties = @{
            roleDefinitionId = "/$($scope)/providers/Microsoft.Authorization/roleDefinitions/$($roleDefinitionId)"
            principalId      = "$principalId"
            requestType      = "AdminAssign"
            scheduleInfo     = @{
                startDateTime = (Get-Date).ToUniversalTime().ToString("o")
                expiration    = @{
                    type        = "NoExpiration" # Values: AfterDuration, AfterDateTime, NoExpiration
                    endDateTime = $null
                    duration    = $null # Use ISO 8601 format ("P365D")
                }
            }
        }
    } | ConvertTo-Json -Depth 10
    $uri = "https://management.azure.com/$($scope)/providers/Microsoft.Authorization/roleEligibilityScheduleRequests/$($roleEligibilityScheduleRequestName)?api-version=2020-10-01"
    
    $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Put -Body $body -SkipHttpErrorCheck
    If ($response.error) {
        If ($response.error.code -eq "RoleAssignmentExists") {
            Add-Logline -Message "Eligible role assignment already exists for principal '$principalId' and roleDefinitionId '$roleDefinitionId' at scope '$scope'" -Severity "Warning"
            return
        }
        else {
            Throw "Error creating eligible assignment: $($response.error.message)"
        }
    } else {
        Add-Logline -Message "Successfully created PIM eligible role assignment for role '$role' at scope '$scope' for principal '$principalId'" -Severity "Info"
    }
}