param(
    [string]$tenantType,
    [string]$UserAssignedIdentityClientId,
    [string]$ContainerName,
    [string]$StorageEndpoint,
    [string]$BlobName,
    [string]$BlobName2,
    [string]$BlobName3
)
If($tenantType -eq "Commercial") {
    $TeamsUrl = "https://teams.microsoft.com/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&download=true"
}
If($tenantType -eq "DepartmentOfDefense") {
    $TeamsUrl = "https://dod.teams.microsoft.us/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&download=true"
}
If($tenantType -eq "GovernmentCommunityCloud") {
    $TeamsUrl = "https://teams.microsoft.com/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&ring=general_gcc&download=true"
}
If($tenantType -eq "GovernmentCommunityCloudHigh") {
    $TeamsUrl = "https://gov.teams.microsoft.us/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&download=true"
}
Write-Host $($TeamsUrl)
$StorageAccountUrl = $StorageEndpoint
$TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$StorageAccountUrl&client_id=$UserAssignedIdentityClientId"
$AccessToken = ((Invoke-WebRequest -Headers @{Metadata=$true} -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
$vcRedistFile = "$env:windir\temp\vc_redist.x64.exe"
$webSocketFile = "$env:windir\temp\webSocketSvc.msi"
$teamsFile = "$env:windir\temp\teams.msi"
Invoke-WebRequest -Headers @{"x-ms-version"="2017-11-09"; Authorization ="Bearer $AccessToken"} -Uri "$StorageAccountUrl$ContainerName/$BlobName" -OutFile $teamsFile
Invoke-WebRequest -Headers @{"x-ms-version"="2017-11-09"; Authorization ="Bearer $AccessToken"} -Uri "$StorageAccountUrl$ContainerName/$BlobName2" -OutFile $vcRedistFile
Invoke-WebRequest -Headers @{"x-ms-version"="2017-11-09"; Authorization ="Bearer $AccessToken"} -Uri "$StorageAccountUrl$ContainerName/$BlobName3" -OutFile  $webSocketFile

# Enable media optimizations for Team
Start-Process "reg" -ArgumentList "add HKLM\SOFTWARE\Microsoft\Teams /v IsWVDEnvironment /t REG_DWORD /d 1 /f" -Wait -PassThru -ErrorAction "Stop"
Write-Host "Enabled media optimizations for Teams"
$ErrorActionPreference = "Stop"
Start-Process -FilePath  $vcRedistFile -Args "/install /quiet /norestart /log vcdist.log" -Wait -PassThru | Out-Null
Write-Host "Installed the latest version of Microsoft Visual C++ Redistributable"
# Download & install the Remote Desktop WebRTC Redirector Service
$ErrorActionPreference = "Stop"
Start-Process -FilePath msiexec.exe -Args "/i  $webSocketFile /quiet /qn /norestart /passive /log webSocket.log" -Wait -PassThru | Out-Null
Write-Host "Installed the Remote Desktop WebRTC Redirector Service"
# Install Teams
$ErrorActionPreference = "Stop"
$sku = (Get-ComputerInfo).OsName
$PerMachineConfiguration = if(($Sku).Contains("multi") -eq "true"){"ALLUSER=1"}else{""}
Start-Process -FilePath msiexec.exe -Args "/i $teamsFile /quiet /qn /norestart /passive /log teams.log $PerMachineConfiguration ALLUSERS=1" -Wait -PassThru | Out-Null
Write-Host "Installed Teams"