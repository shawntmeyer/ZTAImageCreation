param(
    [string]$BuildDir,
    [string]$InstallAccess,
    [string]$InstallExcel,
    [string]$InstallOneDriveForBusiness,
    [string]$InstallOutlook,
    [string]$InstallProject,
    [string]$InstallPublisher,
    [string]$InstallSkypeForBusiness,
    [string]$InstallVisio,
    [string]$InstallWord,
    [string]$InstallOneNote,
    [string]$InstallPowerPoint,
    [string]$UserAssignedIdentityClientId,
    [string]$ContainerName,
    [string]$StorageEndpoint,
    [string]$BlobName
)
$UserAssignedIdentityClientId = $UserAssignedIdentityClientId
$ContainerName = $ContainerName
$BlobName = $BlobName
$StorageAccountUrl = $StorageEndpoint
$TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$StorageAccountUrl&client_id=$UserAssignedIdentityClientId"
$AccessToken = ((Invoke-WebRequest -Headers @{Metadata = $true } -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
$sku = (Get-ComputerInfo).OsName
$appDir = Join-Path -Path $BuildDir -ChildPath 'Office365'
New-Item -Path $appDir -ItemType Directory -Force | Out-Null
$configFile = Join-Path -Path $appDir -ChildPath 'office365x64.xml'
$null =  Set-Content $configFile '<Configuration><Add OfficeClientEdition="64" Channel="Current">'
$null = Add-Content $configFile '<Product ID="O365ProPlusRetail"><Language ID="en-us" /><ExcludeApp ID="Teams"/>'
if ($InstallAccess -notlike '*true*') {
    $null = Add-Content $configFile '<ExcludeApp ID="Access" />'
}
if ($InstallExcel -notlike '*true*') {
    $null= Add-Content $configFile '<ExcludeApp ID="Excel" />'
}
if ($InstallOneDriveForBusiness -notlike '*true*') {
    $null = Add-Content $configFile '<ExcludeApp ID="Groove" />'
}
if ($InstallOneDriveForBusiness -notlike '*true*') {
    $null = Add-Content $configFile '<ExcludeApp ID="Groove" />'
}
if ($InstallOneNote -notlike '*true*') {
    $null = Add-Content $configFile '<ExcludeApp ID="OneNote" />'
}
if ($InstallOutlook -notlike '*true*') {
    $null = Add-Content $configFile '<ExcludeApp ID="Outlook" />'
}
if ($InstallPowerPoint -notlike '*true*') {
    $null = Add-Content $configFile '<ExcludeApp ID="PowerPoint" />'
}
if ($InstallPublisher -notlike '*true*') {
    $null = Add-Content $configFile '<ExcludeApp ID="Publisher" />'
}
if ($InstallSkypeForBusiness -notlike '*true*') {
    $null = Add-Content $configFile '<ExcludeApp ID="Lync" />'
}
if ($InstallWord -notlike '*true*') {
    $null = Add-Content $configFile '<ExcludeApp ID="Word" />'
}
$null = Add-Content $configFile '</Product>'
if ($InstallProject -like '*true*') {
    $null = Add-Content $configFile '<Product ID="ProjectProRetail"><Language ID="en-us" /></Product>'
}
if ($InstallVisio -like '*true*') {
    $null = Add-Content $configFile '<Product ID="VisioProRetail"><Language ID="en-us" /></Product>'
}
$null = Add-Content $configFile '</Add><Updates Enabled="FALSE" /><Display Level="None" AcceptEULA="TRUE" /><Property Name="FORCEAPPSHUTDOWN" Value="TRUE"/>'
if (($Sku).Contains("multi") -eq "true") {
    $null = Add-Content $configFile '<Property Name="SharedComputerLicensing" Value="1"/>'
}
$null = Add-Content $configFile '</Configuration>'
$ErrorActionPreference = "Stop"
$destFile = Join-Path -Path $appDir -ChildPath 'office.zip'
Invoke-WebRequest -Headers @{"x-ms-version" = "2017-11-09"; Authorization = "Bearer $AccessToken" } -Uri "$StorageAccountUrl$ContainerName/$BlobName" -OutFile $destFile
Expand-Archive -Path $destFile -DestinationPath "$appDir\Temp" -Force
$DeploymentTool = (Get-ChildItem -Path $appDir\Temp -Filter '*.exe' -Recurse -File).FullName
Start-Process -FilePath $DeploymentTool -ArgumentList "/extract:`"$appDir\ODT`" /quiet /passive /norestart" -Wait -PassThru | Out-Null
Write-Host "Downloaded & extracted the Office 365 Deployment Toolkit"
$setup = (Get-ChildItem -Path "$appDir\ODT" -Filter '*setup*.exe').FullName
Start-Process -FilePath $setup -ArgumentList "/configure `"$configFile`"" -Wait -PassThru -ErrorAction "Stop" | Out-Null
Write-Host "Installed the selected Office365 applications"