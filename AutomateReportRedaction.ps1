# Switching CISA to tqhjy
# TODO: get the relative path of the JSON file


$jsonFilePath = '.\settings.json'
$newJSONFilePath = '.\updated.json'
#$jsonContent = Get-Content -Path $jsonFilePath -Raw

#$jsonContent = $jsonContent.Replace('cisaent', 'tqhjy')
# Write the updated content back to the JSON file
#$jsonContent | Set-Content -Path $jsonFilePath

# Setting Country, City, BusinessPhone, PostalCode to null

$jsonContent = Get-Content -Path $jsonFilePath | ConvertFrom-Json
# Update the properties
$jsonContent.tenant_details | ForEach-Object {
    $_.AADAdditionalData.City = $null
    $_.AADAdditionalData.Country = $null
    $_.AADAdditionalData.CountryLetterCode = $null
    $_.AADAdditionalData.State = $null
    $_.AADAdditionalData.Street = $null
}
# Convert the updated object back to JSON
$jsonContent = $jsonContent | ConvertTo-Json -Depth 20
# Write the updated content back to the JSON file
$jsonContent | Set-Content -Path $newJSONFilePath