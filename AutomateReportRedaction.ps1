<#
    .SYNOPSIS
        Script to automate Redaction of Sample Reports

    .DESCRIPTION
        This script executes on a generated sample report and replaces items like CISA, cisaent, 
        and any other type of identifiable information with redacted generic information

    .EXAMPLE
        .\RunUnitTests.ps1
        Runs every unit test of every product, no flags necessary

    .EXAMPLE
        .\AutomateReportRedaction
        

#>


# Switching CISA to tqhjy
# TODO: get the relative path of the JSON file


$jsonFilePath = '.\settings.json'
$newJSONFilePath = '.\updated.json'

$jsonContent = Get-Content -Path $jsonFilePath | ConvertFrom-Json

# Setting Country, City, BusinessPhone, PostalCode to null
<#
function Update-Keys {
    param(
        [Parameter(Mandatory=$true)]
        [PSObject]$Object,
        [Parameter(Mandatory=$true)]
        [string[]]$Keys
    )
    $Object.PSObject.Properties | ForEach-Object {
        if ($_.Value -is [PSObject]) {
            Update-Keys -Object $_.Value -Keys $Keys
        }
        elseif ($_.Value -is [array]) {
            if ($_.Name -eq 'BusinessPhones') {
                $_.Value[0] = "1234567890"
            } else {
                $_.Value | ForEach-Object {
                    if ($_ -is [PSObject]) {
                        Update-Keys -Object $_ -Keys $Keys
                    }
                }
            }
        }
        elseif ($Keys -contains $_.Name) {
            $_.Value = $null
        }
    }
}
#>

function Update-Keys {
    param(
        [Parameter(Mandatory=$true)]
        [PSObject]$Object,
        [Parameter(Mandatory=$true)]
        [string[]]$Keys
    )
    $Object.PSObject.Properties | ForEach-Object {
        if ($_.Value -is [PSObject]) {
            Update-Keys -Object $_.Value -Keys $Keys
        }
        elseif ($_.Value -is [array]) {
            if ($_.Name -eq 'BusinessPhones') {
                $_.Value[0] = "1234567890"
            } 
            #TODO FIX
            elseif ($_.Name -eq 'VerifiedDomains') {
                $first = $true
                for ($i=0; $i -lt $_.Value.Count; $i++) {
                    if ($_.Value[$i].Name -eq 'tqhjy.onmicrosoft.com' -and $_.Value[$i].Capabilities -match 'Email' -and $_.Value[$i].Capabilities -match 'OfficeCommunicationsOnline') {
                        if ($first) {
                            $first = $false
                        } else {
                            $_.Value[$i] = $null
                        }
                    } else {
                        $_.Value[$i] = $null
                    }
                }
                $_.Value = $_.Value | Where-Object { $_ -ne $null }
            } 
            elseif ($_.Name -eq 'TechnicalNotificationMails') {
                $_.Value = @("admin@example.com")
            }
            elseif ($_.Name -eq 'notificationRecipients' -and $_.Value.Count -gt 0) {
                $_.Value = @("admin@example.com")
            } 
            else {
                for ($i=0; $i -lt $_.Value.Count; $i++) {
                    if ($_.Value[$i] -is [PSObject]) {
                        Update-Keys -Object $_.Value[$i] -Keys $Keys
                    }
                }
            }
        }
        elseif ($Keys -contains $_.Name) {
            $_.Value = $null
        }        
    }
}

# Specify the keys to update
$keysToUpdate = @('BusinessPhones','City', 'Country', 'CountryLetterCode', 'CountryAbbreviation', 'State', 'Street', 'PostalCode')

# Update the keys
Update-Keys -Object $jsonContent -Keys $keysToUpdate
$jsonString = $jsonContent | ConvertTo-Json -Depth 20
$jsonString = $jsonString -replace 'Cybersecurity and Infrastructure Security Agency', 'tqhjy'
$jsonString = $jsonString -replace 'cisaent.mail', 'tqhjy'
$jsonString = $jsonString -replace 'cisaent', 'tqhjy'
#$jsonString = $jsonString -replace 'cisa', 'SCuBA'
$jsonContent = $jsonString | ConvertFrom-Json
$jsonContent | ConvertTo-Json -Depth 20 | Set-Content -Path $newJSONFilePath