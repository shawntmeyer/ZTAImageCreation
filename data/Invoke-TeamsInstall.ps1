param(
    [string]$BuildDir,
    [string]$UserAssignedIdentityClientId,
    [string]$ContainerName,
    [string]$StorageEndpoint,
    [string]$BlobName
)
$TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$StorageEndpoint&client_id=$UserAssignedIdentityClientId"
$AccessToken = ((Invoke-WebRequest -Headers @{Metadata=$true} -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
$sku = (Get-ComputerInfo).OsName
$appDir = Join-Path -Path $BuildDir -ChildPath 'Teams'
New-Item -Path $appDir -ItemType Directory -Force | Out-Null
$destFile = Join-Path -Path $appDir -ChildPath 'Teams.zip'
Invoke-WebRequest -Headers @{"x-ms-version"="2017-11-09"; Authorization ="Bearer $AccessToken"} -Uri "$StorageEndpoint$ContainerName/$BlobName" -OutFile $destFile
Expand-Archive -Path $destFile -DestinationPath $appDir -Force
$vcRedistFile = (Get-ChildItem -Path $appDir -filter 'vc*.exe' -Recurse).FullName
$webRTCFile = (Get-ChildItem -Path $appDir -filter '*WebRTC*.msi' -Recurse).FullName
$teamsFile = (Get-ChildItem -Path $appDir -filter '*Teams*.msi' -Recurse).FullName
# Enable media optimizations for Team
New-Item -Path "HKLM:\SOFTWARE\Microsoft\Teams" -Force
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Teams" -Name IsWVDEnvironment -PropertyType DWORD -Value 1 -Force
Write-Host "Enabled media optimizations for Teams"
$ErrorActionPreference = "Stop"
Start-Process -FilePath  $vcRedistFile -Args "/install /quiet /norestart" -Wait -PassThru | Out-Null
Write-Host "Installed the latest version of Microsoft Visual C++ Redistributable"
# install the Remote Desktop WebRTC Redirector Service
Start-Process -FilePath msiexec.exe -Args "/i  $webRTCFile /quiet /qn /norestart /passive" -Wait -PassThru | Out-Null
Write-Host "Installed the Remote Desktop WebRTC Redirector Service"
# Install Teams
if(($Sku).Contains('multi')){
    $msiArgs = 'ALLUSER=1 ALLUSERS=1'
} else {
    $msiArgs = 'ALLUSERS=1'
}
Start-Process -FilePath msiexec.exe -Args "/i $teamsFile /quiet /qn /norestart /passive $msiArgs" -Wait -PassThru | Out-Null
Write-Host "Installed Teams"