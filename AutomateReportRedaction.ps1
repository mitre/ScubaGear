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
$sampleGUID = 'ca08493a-c9c8-4db0-a9e8-d3b4bafac269'
$privilegedUsersFilePath = '.\redacted_privileged_users.json'
$privilegedUsers = Get-Content -Path $privilegedUsersFilePath | ConvertFrom-Json


$jsonContent = Get-Content -Path $jsonFilePath | ConvertFrom-Json


function Update-Keys {
    param(
        [Parameter(Mandatory=$true)]
        [PSObject]$Object,
        [Parameter(Mandatory=$true)]
        [string[]]$Keys
    )
    $Object.PSObject.Properties | ForEach-Object {
        if ($_.Name -eq 'TenantId' -or $_.Name -eq 'tenantId') {
            $_.Value = $sampleGUID
        }

        elseif ($_.Name -eq 'privileged_users') {
            $_.Value = $privilegedUsers
        }

        elseif ($_.Name -eq 'primaryApprovers') {
            $_.Value = @(
                @{
                    "@odata.type" = "#microsoft.graph.groupMembers"
                    "isBackup" = $false
                    "id" = "54e56ffb-a568-4c65-b04a-7a6feabab17c"
                    "description" = "privileged escalation approvers"
                }
            )
        }

        elseif ($_.Name -eq 'properties' -and $_.Value -is [string]) {
            $_.Value = $_.Value -replace '(tenantId=)[^;]*', "`$1$sampleGUID"
        }

        elseif ($_.Value -is [PSObject]) {
            Update-Keys -Object $_.Value -Keys $Keys
        }
        elseif ($_.Value -is [array]) {
            if ($_.Name -eq 'BusinessPhones') {
                $_.Value[0] = "1234567890"
            } 
            elseif ($_.Name -eq 'TechnicalNotificationMails') {
                $_.Value = @("admin@example.com")
            }
            elseif ($_.Name -eq 'notificationRecipients' -and $_.Value.Count -gt 0) {
                $_.Value = @("admin@example.com")
            } 

            elseif ($_.Name -eq 'VerifiedDomains') {
                $firstVerifiedDomain = $_.Value | Where-Object { $_.Name -eq 'cisaent.onmicrosoft.com' -and $_.Capabilities -match 'Email' -and $_.Capabilities -match 'OfficeCommunicationsOnline' } | Select-Object -First 1
                if ($firstVerifiedDomain) {
                    $_.Value = @($firstVerifiedDomain)
                }
            }
            elseif ($_.Name -eq 'cap_table_data' -or $_.Name -eq 'conditional_access_policies') {
                $_.Value = $_.Value | Where-Object { $_.DisplayName -match '^(Live|MS\.\w+\.\d+\.\d+v\d+)' }
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