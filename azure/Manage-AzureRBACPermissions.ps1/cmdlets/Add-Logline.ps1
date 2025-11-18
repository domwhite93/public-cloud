function Add-Logline {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 1)]
        [string]
        $Message,

        [Parameter(Position = 2)]
        [string]
        $logfile,

        [Parameter(Position = 3)]
        [ValidateSet('Info', 'Warning', 'Error', 'Verbose')]
        [string]
        $Severity = "Info",

        [Parameter(Position = 4)]
        [string]
        $TimestampFormat = "dd/MM/yy HH:mm:ss"
    )

    process {
        try {
            # Use default log file if none is provided
            if (-not $logfile) {
                if (-not $Global:DefaultLogFile) {
                    throw "No log file specified, and no default log file is set."
                }
                $logfile = $Global:DefaultLogFile
            }
            
            # Get timestamp
            $timestamp = "[{0:$TimestampFormat}]" -f (Get-Date)

            # Ensure log file exists
            if (!(Test-Path $logfile)) {
                New-Item -ItemType File -Path $logfile -Force | Out-Null
            }

            # Generate log message
            $LogFileNewLine = "$timestamp : $($Severity.Substring(0, 4)) : $Message`n"

            # Write to log file
            if (($Severity -ne "Verbose") -or ($VerbosePreference -ne "SilentlyContinue")) {
                [System.IO.File]::AppendAllText($logfile, $LogFileNewLine)
            }

            # Generate output message
            $OutputStreamNewLine = "$timestamp : $Message"

            # Write to appropriate stream
            switch ($Severity) {
                "Info" { Write-Information $OutputStreamNewLine ; Write-Host $OutputStreamNewLine }
                "Warning" { Write-Warning $OutputStreamNewLine }
                "Error" { Write-Error $OutputStreamNewLine }
                "Verbose" { Write-Verbose $OutputStreamNewLine }
            }
        }
        catch {
            Write-Error "Failed to write to log file: $($_.Exception.Message)"
        }
    }
}