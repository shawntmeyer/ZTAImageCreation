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
$ErrorActionPreference = "Stop"
$destFile = Join-Path -Path $appDir -ChildPath 'office.zip'
Invoke-WebRequest -Headers @{"x-ms-version" = "2017-11-09"; Authorization = "Bearer $AccessToken" } -Uri "$StorageEndpoint$ContainerName/$BlobName" -OutFile $destFile
Expand-Archive -Path $destFile -DestinationPath "$appDir\Temp" -Force
$Setup = (Get-ChildItem -Path $appDir\Temp -Filter 'setup*.exe' -Recurse -File).FullName
If (-not($Setup)) {
    $DeploymentTool = (Get-ChildItem -Path $appDir\Temp -Filter 'OfficeDeploymentTool*.exe' -Recurse -File).FullName
    Start-Process -FilePath $DeploymentTool -ArgumentList "/extract:`"$appDir\ODT`" /quiet /passive /norestart" -Wait -PassThru | Out-Null
    Write-Output "Downloaded & extracted the Office 365 Deployment Toolkit"
    $setup = (Get-ChildItem -Path "$appDir\ODT" -Filter '*setup*.exe').FullName
}
$configFile = Join-Path -Path $appDir -ChildPath 'office365x64.xml'
$null = Set-Content $configFile '<Configuration>'
$null = Add-Content $configFile '  <Add OfficeClientEdition="64" Channel="MonthlyEnterprise">'
$null = Add-Content $configFile '    <Product ID="O365ProPlusRetail">'
$null = Add-Content $configFile '      <Language ID="en-us" />'
$null = Add-Content $configFile '      <ExcludeApp ID="Groove" />'
$null = Add-Content $configFile '      <ExcludeApp ID="OneDrive" />'
$null = Add-Content $configFile '      <ExcludeApp ID="Teams" />'
if ($InstallAccess -ne 'True') {
    $null = Add-Content $configFile '      <ExcludeApp ID="Access" />'
}
if ($InstallExcel -ne 'True') {
    $null = Add-Content $configFile '      <ExcludeApp ID="Excel" />'
}
if ($InstallOneNote -ne 'True') {
    $null = Add-Content $configFile '      <ExcludeApp ID="OneNote" />'
}
if ($InstallOutlook -ne 'True') {
    $null = Add-Content $configFile '      <ExcludeApp ID="Outlook" />'
}
if ($InstallPowerPoint -ne 'True') {
    $null = Add-Content $configFile '      <ExcludeApp ID="PowerPoint" />'
}
if ($InstallPublisher -ne 'True') {
    $null = Add-Content $configFile '      <ExcludeApp ID="Publisher" />'
}
if ($InstallSkypeForBusiness -ne 'True') {
    $null = Add-Content $configFile '      <ExcludeApp ID="Lync" />'
}
if ($InstallWord -ne 'True') {
    $null = Add-Content $configFile '      <ExcludeApp ID="Word" />'
}
$null = Add-Content $configFile '    </Product>'
if ($InstallProject -eq 'True') {
    $null = Add-Content $configFile '    <Product ID="ProjectProRetail"><Language ID="en-us" /></Product>'
}
if ($InstallVisio -eq 'True') {
    $null = Add-Content $configFile '    <Product ID="VisioProRetail"><Language ID="en-us" /></Product>'
}
$null = Add-Content $configFile '  </Add>'
if (($Sku).Contains("multi") -eq "true") {
    $null = Add-Content $configFile '  <Property Name="SharedComputerLicensing" Value="1" />'
}
$null = Add-Content $configFile '  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />'
$null = Add-Content $configFile '  <Updates Enabled="FALSE" />'
$null = Add-Content $configFile '  <Display Level="None" AcceptEULA="TRUE" />'
$null = Add-Content $configFile '</Configuration>'
Start-Process -FilePath $setup -ArgumentList "/configure `"$configFile`"" -Wait -PassThru -ErrorAction "Stop" | Out-Null
Write-Output "Installed the selected Office365 applications"