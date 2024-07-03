#Requires -Version 5.1


function New-PrivateGallery {
  <#
    .Description
    Creates a new private package repository (i.e., gallery) on local file system
    .Parameter GalleryPath
    Path for directory to use for private gallery
    .Parameter GalleryName
    Name of the private gallery
    .Parameter Trusted
    Indicates if private gallery is registered as a trusted gallery
    .Example
    New-PrivateGallery -Trusted
    Create new private, trusted gallery using default name and location
    #>
  [CmdletBinding(SupportsShouldProcess)]
  param (
    [Parameter(Mandatory = $false)]
    [ValidateScript({ Test-Path -Path $_ -IsValid })]
    [string]
    $GalleryRootPath = $env:TEMP,
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $GalleryName = 'PrivateScubaGearGallery',
    [switch]
    $Trusted
  )

  $GalleryPath = Join-Path -Path $GalleryRootPath -ChildPath $GalleryName
  if (Test-Path $GalleryPath) {
    Write-Debug "Removing private gallery at $GalleryPath"
    Remove-Item -Recursive -Force $GalleryPath
  }

  New-Item -Path $GalleryPath -ItemType Directory

  if (-not (IsRegistered -RepoName $GalleryName)) {
    Write-Debug "Attempting to register $GalleryName repository"

    $Splat = @{
      Name               = $GalleryName
      SourceLocation     = $GalleryPath
      PublishLocation    = $GalleryPath
      InstallationPolicy = if ($Trusted) { 'Trusted' } else { 'Untrusted' }
    }

    Register-PSRepository @Splat
  }
  else {
    Write-Warning "$GalleryName is already registered. You can unregister: `nUnregister-PSRepository -Name $GalleryName"
  }
}

function IsRegistered {
  <#
        .NOTES
            Internal helper function
    #>
  param (
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $RepoName = 'PrivateScubaGearGallery'
  )

  Write-Debug "Looking for $RepoName local repository"
  $Registered = $false
  try {
    $Registered = (Get-PSRepository).Name -contains $RepoName
  }
  catch {
    Write-Error "Failed to check IsRegistered: $_"
  }
  return $Registered
}

function Publish-ScubaGearModule {
  <#
    .Description
      Publish ScubaGear module to private package repository
    .Parameter AzureKeyVaultUrl
      The URL of the key vault with the code signing certificate
    .Parameter CertificateName
      The name of the code signing certificate
    .Parameter ModulePath
      Path to module root directory
    .Parameter GalleryName
      Name of the private package repository (i.e., gallery)
    .Parameter OverrideModuleVersion
      Optional module version.  If provided it will use as module version. Otherwise, the current version from the manifest with a revision number is added instead.
    .Parameter PrereleaseTag
      The identifier that will be used in place of a version to identify the module in the gallery
    .Parameter NuGetApiKey
      Specifies the API key that you want to use to publish a module to the online gallery.
  #>
  param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({ [uri]::IsWellFormedUriString($_, 'Absolute') -and ([uri] $_).Scheme -in 'https' })]
    [System.Uri]
    $AzureKeyVaultUrl,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $CertificateName,
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [string]
    $ModuleSourcePath,
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $GalleryName = 'PrivateScubaGearGallery',
    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]
    $OverrideModuleVersion = "",
    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]
    $PrereleaseTag = "",
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]
    $NuGetApiKey
  )

  Write-Output "Copying the module to a temp location..."
  $ModuleDestinationPath = Copy-ModuleToTempLocation `
   -ModuleSourcePath $ModuleSourcePath `
   -ModuleTempPath $env:TEMP

  Write-Output "Editing the manifest file..."
  Edit-TheManifestFile `
   -ModuleDestinationPath $ModuleDestinationPath `
   -OverrideModuleVersion $OverrideModuleVersion `
   -PrereleaseTag $PrereleaseTag

  Write-Output "Creating an array of the files to sign..."
  $ArrayOfFilePaths = New-ArrayOfFilePaths `
   -ModuleDestinationPath $ModuleDestinationPath
  
  Write-Output "Creating a file with a list of the files to sign..."
  $FileListFileName = New-FileList `
   -ArrayOfFilePaths $ArrayOfFilePaths

  Write-Warning "Calling AzureSignTool function to sign scripts, manifest, and modules..."
  CallAzureSignTool `
    -AzureKeyVaultUrl $AzureKeyVaultUrl `
    -CertificateName $CertificateName `
    -FileList $FileListFileName

  # Create and sign catalog
  $CatalogFileName = 'ScubaGear.cat'
  $CatalogFilePath = Join-Path -Path $ModuleDestinationPath -ChildPath $CatalogFileName

  if (Test-Path -Path $CatalogFilePath -PathType Leaf) {
    Remove-Item -Path $CatalogFilePath -Force
  }

  # New-FileCatlog creates a Windows catalog file (.cat) containing cryptographic hashes
  # for files and folders in the specified paths.
  $CatalogFilePath = New-FileCatalog -Path $ModuleDestinationPath -CatalogFilePath $CatalogFilePath -CatalogVersion 2.0
  Write-Warning ">> The catalog path is $CatalogFilePath"
  $CatalogList = New-TemporaryFile
  $CatalogFilePath.FullName | Out-File -FilePath $CatalogList -Encoding utf8 -Force

  Write-Warning ">> Calling CallAzureSignTool function to sign catalog list..."
  CallAzureSignTool `
    -AzureKeyVaultUrl $AzureKeyVaultUrl `
    -CertificateName $CertificateName `
    -FileList $CatalogList
    # -TimeStampServer $TimeStampServer `

  # Test-FileCatalog validates whether the hashes contained in a catalog file (.cat) matches
  # the hashes of the actual files in order to validate their authenticity.
  Write-Warning ">> Testing the catalog"
  $TestResult = Test-FileCatalog -Path $ModuleDestinationPath -CatalogFilePath $CatalogFilePath
  Write-Warning ">> Test result is $TestResult"
  if ('Valid' -eq $TestResult) {
    Write-Warning ">> Signing the module was successful."
  }
  else {
    Write-Error ">> Signing the module was NOT successful."
  }

  $Parameters = @{
    Path       = $ModuleDestinationPath
    Repository = $GalleryName
  }
  if ($GalleryName -eq 'PSGallery') {
    $Parameters.Add('NuGetApiKey', $NuGetApiKey)
  }

  Write-Output "> The ScubaGear module will be published."
  # The -Force parameter is only required if the new version is less than or equal to
  # the current version, which is typically only true when testing.
  # Publish-Module @Parameters -Force

}

function Copy-ModuleToTempLocation {
  <#
    .DESCRIPTION
      Copies the module source path to a temp location, keeping the name of the leaf folder the same.
      Throws an error if the copy fails.
      Returns the module destination path.
  #>
  param (
    [Parameter(Mandatory = $true)]
    [string]
    $ModuleSourcePath,
    [Parameter(Mandatory = $true)]
    [string]
    $ModuleTempPath
 )

  $Leaf = Split-Path -Path $ModuleSourcePath -Leaf
  $ModuleDestinationPath = Join-Path -Path $ModuleTempPath -ChildPath $Leaf

  Write-Warning "The module source path is $ModuleSourcePath"
  Write-Warning "The temp path is $ModuleTempPath"
  Write-Warning "The module destination path is $ModuleDestinationPath"

  # Remove the destination if it already exists
  if (Test-Path -Path $ModuleDestinationPath -PathType Container) {
    Remove-Item -Recurse -Force $ModuleDestinationPath
  }

  Write-Warning "Copying the module from source to dest..."

  Copy-Item $ModuleSourcePath -Destination $ModuleDestinationPath -Recurse

  # Verify that the destination exists
  if (Test-Path -Path $ModuleDestinationPath) {
    Write-Warning "The module desintination path exists."
  }
  else {
    Write-Error "Failed to find the module desintination path."
  }

  return $ModuleDestinationPath
}

function Edit-TheManifestFile {
  <#
    .DESCRIPTION
      Updates the manifest file in the module with info that PSGallery needs
      Throws an error if the manifest file cannot be found or updated.
      No return.
  #>
  param (
    [Parameter(Mandatory = $true)]
    [string]
    $ModuleDestinationPath,
    [Parameter(Mandatory = $false)]
    [string]
    $OverrideModuleVersion,
    [Parameter(Mandatory = $true)][AllowEmptyString()]
    [string]
    $PrereleaseTag
 )

  $ManifestFilePath = Join-Path -Path $ModuleDestinationPath -ChildPath "ScubaGear.psd1"

  Write-Warning "The manifest file path is $ManifestFilePath"

  # Verify that the manifest file exists
  if (Test-Path -Path $ManifestFilePath) {
    Write-Warning "The manifest file exists."
  }
  else {
    Write-Error "Failed to find the manifest file."
  }

  # The module needs some version
  if ([string]::IsNullOrEmpty($OverrideModuleVersion)) {
    # If the override module version is missing, make up some version
    $CurrentModuleVersion = (Import-PowerShellDataFile $ManifestFilePath).ModuleVersion
    $TimeStamp = [int32](Get-Date -UFormat %s)
    $ModuleVersion = "$CurrentModuleVersion.$TimeStamp"
  }
  else {
    # Use what the user supplied
    $ModuleVersion = $OverrideModuleVersion
  }

  Write-Warning "The module version is $ModuleVersion"
  Write-Warning "The prerelease tag is $PrereleaseTag" # Can be empty

  $ProjectUri = "https://github.com/cisagov/ScubaGear"
  $LicenseUri = "https://github.com/cisagov/ScubaGear/blob/main/LICENSE"
  # Tags cannot contain spaces
  $Tags = 'CISA', 'O365', 'M365', 'AzureAD', 'Configuration', 'Exchange', 'Report', 'Security', 'SharePoint', 'Defender', 'Teams', 'PowerPlatform', 'OneDrive'

  # Configure the update parameters for the manifest file
  $ManifestUpdates = @{
    Path          = $ManifestFilePath
    ModuleVersion = $ModuleVersion
    ProjectUri    = $ProjectUri
    LicenseUri    = $LicenseUri
    Tags          = $Tags
  }
  if (-Not [string]::IsNullOrEmpty($PrereleaseTag)) {
    $ManifestUpdates.Add('Prerelease', $PrereleaseTag)
  }

  try {
    $CurrentErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    Update-ModuleManifest @ManifestUpdates
    $ErrorActionPreference = $CurrentErrorActionPreference
  }
  catch {
    Write-Warning "Error: Cannot edit the module because:"
    Write-Warning $_.Exception
    Write-Error "Failed to edit the module manifest."
  }
  try {
    $CurrentErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    Test-ModuleManifest -Path $ManifestFilePath
    $ErrorActionPreference = $CurrentErrorActionPreference
  }
  catch {
    Write-Warning "Error: Cannot test the manifest file because:"
    Write-Warning $_.Exception
    Write-Error "Failed to test the manifest file."
  }
}

function New-ArrayOfFilePaths {
  <#
    .DESCRIPTION
      Creates an array of the files to sign
      Throws an error if no matching files can be found.
      Returns the array.
  #>
  param (
    [Parameter(Mandatory = $true)]
    [string]
    $ModuleDestinationPath
 )

  $FileExtensions = "*.ps1", "*.psm1", "*.psd1"  # Array of extensions to match on
  
  $ArrayOfFilePaths = @()
  $ArrayOfFilePaths = Get-ChildItem -Recurse -Path $ModuleDestinationPath -Include $FileExtensions
  
  # Write-Warning "Verifying array of file paths..."
  # ForEach ($FilePath in $ArrayOfFilePaths) {
  #     Write-Warning ">>> File path is $FilePath"
  # }

  if ($ArrayOfFilePaths.Length -gt 0) {
    Write-Warning "Found $($ArrayOfFilePaths.Count) files to sign"
  }
  else {
    Write-Error "Failed to find any .ps1, .psm1, or .psd files."    
  }

  return $ArrayOfFilePaths
}

function New-FileList {
  <#
    .DESCRIPTION
      Creates a file that contains a list of all the files to sign
      Throws an error if the file is not created.
      Returns the name of the file.
  #>
  param (
    [Parameter(Mandatory = $true)]
    [string]
    $ArrayOfFilePaths
 )
  $FileListPath = New-TemporaryFile
  $ArrayOfFilePaths.FullName | Out-File -FilePath $($FileList.FullName) -Encoding utf8 -Force
  $FileListFileName = $FileListPath.FullName

  # Verify that the file exists
  if (Test-Path -Path $FileListPath) {
    Write-Warning "The list file exists."
  }
  else {
    Write-Error "Failed to find the list file."
  }

  return $FileListFileName
}

function CallAzureSignTool {
  <#
    .NOTES
      Internal function
      AzureSignTool is a utility for signing code that is used to secure ScubaGear.
      https://github.com/vcsjones/AzureSignTool
  #>
  param (
    [Parameter(Mandatory = $true)]
    [ValidateScript({ [uri]::IsWellFormedUriString($_, 'Absolute') -and ([uri] $_).Scheme -in 'https' })]
    [System.Uri]
    $AzureKeyVaultUrl,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $CertificateName,
    [Parameter(Mandatory = $false)]
    [ValidateScript({ [uri]::IsWellFormedUriString($_, 'Absolute') -and ([uri] $_).Scheme -in 'http', 'https' })]
    $TimeStampServer = 'http://timestamp.digicert.com',
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
    $FileList
  )

  Write-Warning ">>> Running the AzureSignTool method..."

  $SignArguments = @(
    'sign',
    '-coe',
    '-fd', "sha256",
    '-tr', $TimeStampServer,
    '-kvu', $AzureKeyVaultUrl,
    '-kvc', $CertificateName,
    '-kvm'
    '-ifl', $FileList
  )

  Write-Warning ">>> The files to sign are in the temp file $FileList"
  # Get-Command returns a System.Management.Automation.ApplicationInfo
  $NumberOfCommands = (Get-Command AzureSignTool) # Should return 1
  if ($NumberOfCommands -eq 0) {
    Write-Error "Failed to find the AzureSignTool on this system."
  }
  $ToolPath = (Get-Command AzureSignTool).Path
  Write-Warning ">>> The path to AzureSignTool is $ToolPath"
  $Results = & $ToolPath $SignArguments
  # Write-Warning ">>> Results"
  # Write-Warning $Results

  # Test the results for failures.
  # If there are no failures, this string will be the last line in the results.
  # Warning: This is a brittle test, because it depends upon a specific string.
  # A unit test should be used to detect changes.
  $FoundNoFailures = $Results | Select-String -Pattern 'Failed operations: 0' -Quiet
  if ($FoundNoFailures -eq $true) {
    Write-Warning ">>> Found no failures."
  }
  else {
    Write-Error ">>> Failed to sign the filelist without errors."
  }
}
