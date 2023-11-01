param(
    [string]$BuildDir,
    [string]$InstallAccess,
    [string]$InstallExcel,
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
$TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$StorageEndpoint&client_id=$UserAssignedIdentityClientId"
$AccessToken = ((Invoke-WebRequest -Headers @{Metadata = $true } -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
$sku = (Get-ComputerInfo).OsName
$appDir = Join-Path -Path $BuildDir -ChildPath 'Office365'
New-Item -Path $appDir -ItemType Directory -Force | Out-Null
$configFile = Join-Path -Path $appDir -ChildPath 'office365x64.xml'
$null = Set-Content $configFile '<Configuration><Add OfficeClientEdition="64" Channel="Current">'
$null = Add-Content $configFile '<Product ID="O365ProPlusRetail">'
$null = Add-Content $configFile '<Language ID="en-us" />'
$null = Add-Content $configFile '<ExcludeApp ID="Groove" />'
$null = Add-Content $configFile '<ExcludeApp ID="Teams"/>'
if ($InstallAccess -ne 'true') {
    $null = Add-Content $configFile '<ExcludeApp ID="Access" />'
}
if ($InstallExcel -ne 'true') {
    $null= Add-Content $configFile '<ExcludeApp ID="Excel" />'
}
if ($InstallOneNote -ne 'true') {
    $null = Add-Content $configFile '<ExcludeApp ID="OneNote" />'
}
if ($InstallOutlook -ne 'true') {
    $null = Add-Content $configFile '<ExcludeApp ID="Outlook" />'
}
if ($InstallPowerPoint -ne 'true') {
    $null = Add-Content $configFile '<ExcludeApp ID="PowerPoint" />'
}
if ($InstallPublisher -ne 'true') {
    $null = Add-Content $configFile '<ExcludeApp ID="Publisher" />'
}
if ($InstallSkypeForBusiness -ne 'true') {
    $null = Add-Content $configFile '<ExcludeApp ID="Lync" />'
}
if ($InstallWord -ne 'true') {
    $null = Add-Content $configFile '<ExcludeApp ID="Word" />'
}
$null = Add-Content $configFile '</Product>'
if ($InstallProject -eq 'true') {
    $null = Add-Content $configFile '<Product ID="ProjectProRetail"><Language ID="en-us" /></Product>'
}
if ($InstallVisio -eq 'true') {
    $null = Add-Content $configFile '<Product ID="VisioProRetail"><Language ID="en-us" /></Product>'
}
$null = Add-Content $configFile '</Add><Updates Enabled="FALSE" /><Display Level="None" AcceptEULA="TRUE" /><Property Name="FORCEAPPSHUTDOWN" Value="TRUE"/>'
if (($Sku).Contains("multi") -eq "true") {
    $null = Add-Content $configFile '<Property Name="SharedComputerLicensing" Value="1"/>'
}
$null = Add-Content $configFile '</Configuration>'
$ErrorActionPreference = "Stop"
$destFile = Join-Path -Path $appDir -ChildPath 'office.zip'
Invoke-WebRequest -Headers @{"x-ms-version" = "2017-11-09"; Authorization = "Bearer $AccessToken" } -Uri "$StorageEndpoint$ContainerName/$BlobName" -OutFile $destFile
Expand-Archive -Path $destFile -DestinationPath "$appDir\Temp" -Force
$Setup = (Get-ChildItem -Path $appDir\Temp -Filter 'setup*.exe' -Recurse -File).FullName
If (-not($Setup)) {
    $DeploymentTool = (Get-ChildItem -Path $appDir\Temp -Filter 'OfficeDeploymentTool*.exe' -Recurse -File).FullName
    Start-Process -FilePath $DeploymentTool -ArgumentList "/extract:`"$appDir\ODT`" /quiet /passive /norestart" -Wait -PassThru | Out-Null
    Write-Host "Downloaded & extracted the Office 365 Deployment Toolkit"
    $setup = (Get-ChildItem -Path "$appDir\ODT" -Filter '*setup*.exe').FullName
}
Start-Process -FilePath $setup -ArgumentList "/configure `"$configFile`"" -Wait -PassThru -ErrorAction "Stop" | Out-Null
Write-Host "Installed the selected Office365 applications"