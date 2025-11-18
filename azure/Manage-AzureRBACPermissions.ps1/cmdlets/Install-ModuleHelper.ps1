function Install-ModuleHelper {
    [CmdletBinding()]
    param (
        [string]$module
    )
    process {
        if (-not (Get-Module $module -ListAvailable)) {
            Add-Logline -Message "Prerequisites: Powershell-Module '$module' not installed - try to install" -logfile $logfile -Severity Info
            Try {
                Install-Module $module -Scope CurrentUser -Force -AllowClobber
                Add-Logline -Message "Prerequisites: successfully installed Powershell-Module '$module' - continue script!" -logfile $logfile -Severity Info
            }
            Catch {
                Add-Logline -Message "Prerequisites: Error installing Powershell-Mdoule '$module' - aborting script!" -logfile $logfile -Severity Error
            }
        }
    }
}