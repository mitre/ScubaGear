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
            } else {
                for ($i=0; $i -lt $_.Value.Count; $i++) {
                    if ($_.Value[$i] -is [PSObject]) {
                        Update-Keys -Object $_.Value[$i] -Keys $Keys
                    }
                    elseif ($_.Value[$i] -match 'cisaent') {
                        $_.Value[$i] = $_.Value[$i] -replace 'cisaent', 'tqhjy'
                    }
                    elseif ($_.Value[$i] -match 'cisaent.mail') {
                        $_.Value[$i] = $_.Value[$i] -replace 'cisaent.mail', 'tqhjy'
                    }
                }
            }
        }
        elseif ($Keys -contains $_.Name) {
            $_.Value = $null
        }
        
        elseif ($_.Value -match 'cisaent.mail') {
            $_.Value = $_.Value -replace 'cisaent.mail', 'tqhjy'
        }
        
        elseif ($_.Value -match 'cisaent') {
            $_.Value = $_.Value -replace 'cisaent', 'tqhjy'
        }

        elseif ($_.Value -match 'cisa') {
            $_.Value = $_.Value -replace 'cisa', 'tqhjy'
        }

        <#elseif ($_.Value -match 'cisa') {
            $_.Value = $_.Value -replace 'cisa', 'tqhjy'
        }#>
        
    }
}

# Specify the keys to update
$keysToUpdate = @('BusinessPhones','City', 'Country', 'CountryLetterCode', 'CountryAbbreviation', 'State', 'Street', 'PostalCode')
# Update the keys
Update-Keys -Object $jsonContent -Keys $keysToUpdate
# Convert the updated object back to JSON
$jsonContent = $jsonContent | ConvertTo-Json -Depth 20
# Write the updated content back to the JSON file
$jsonContent | Set-Content -Path $newJSONFilePath