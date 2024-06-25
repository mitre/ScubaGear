# Switching CISA to tqhjy
# TODO: get the relative path of the JSON file


$jsonFilePath = '.\settings.json'
$newJSONFilePath = '.\updated.json'
#$jsonContent = Get-Content -Path $jsonFilePath -Raw

#$jsonContent = $jsonContent.Replace('cisaent', 'tqhjy')
# Write the updated content back to the JSON file
#$jsonContent | Set-Content -Path $jsonFilePath

$jsonContent = Get-Content -Path $jsonFilePath | ConvertFrom-Json

# Setting Country, City, BusinessPhone, PostalCode to null

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


# Specify the keys to update
$keysToUpdate = @('BusinessPhones','City', 'Country', 'CountryLetterCode', 'CountryAbbreviation', 'State', 'Street', 'PostalCode')
# Update the keys
Update-Keys -Object $jsonContent -Keys $keysToUpdate
# Convert the updated object back to JSON
$jsonContent = $jsonContent | ConvertTo-Json -Depth 20
# Write the updated content back to the JSON file
$jsonContent | Set-Content -Path $newJSONFilePath