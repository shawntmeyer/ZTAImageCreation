param(
    [string]$BuildDir,
    [string]$UserAssignedIdentityClientId,
    [string]$ContainerName,
    [string]$StorageEndpoint,
    [string]$BlobName
)
$RegPath = 'HKLM:\SOFTWARE\Microsoft\OneDrive'
If (Test-Path -Path $RegPath) {
    If (Get-ItemProperty -Path $RegPath -Name AllUsersInstall -ErrorAction SilentlyContinue) {
        $AllUsersInstall = Get-ItemPropertyValue -Path $RegPath -Name AllUsersInstall
    }
}
If ($AllUsersInstall -eq '1') {
    Write-Host "OneDrive is already setup per-machine. Quiting."
} Else {
    Write-Host "Obtaining bearer token for download from Azure Storage Account."
    $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$StorageEndpoint&client_id=$UserAssignedIdentityClientId"
    $AccessToken = ((Invoke-WebRequest -Headers @{Metadata=$true} -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
    $appDir = Join-Path -Path $BuildDir -ChildPath 'OneDrive'
    New-Item -Path $appDir -ItemType Directory -Force | Out-Null
    $destFile = Join-Path -Path $appDir -ChildPath 'OneDrive.zip'
    Invoke-WebRequest -Headers @{"x-ms-version"="2017-11-09"; Authorization ="Bearer $AccessToken"} -Uri "$StorageEndpoint$ContainerName/$BlobName" -OutFile $destFile
    Expand-Archive -Path $destFile -DestinationPath $appDir -Force
    $onedrivesetup = (Get-ChildItem -Path $appDir -filter 'OneDrive*.exe' -Recurse).FullName
    #Find existing OneDriveSetup
    $RegPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe'
    If (Test-Path -Path $RegPath) {
        If (Get-ItemProperty -Path $RegPath -name UninstallString -ErrorAction SilentlyContinue) {
            $UninstallString = (Get-ItemPropertyValue -Path $RegPath -Name UninstallString).toLower()
            $OneDriveSetupindex = $UninstallString.IndexOf('onedrivesetup.exe') + 17
            $Uninstaller = $UninstallString.Substring(0,$OneDriveSetupindex)
            $Arguments = $UninstallString.Substring($OneDriveSetupindex).replace('  ', ' ').trim()
        }
    } Else {
        $Uninstaller = $OneDriveSetup
        $Arguments = '/uninstall'
    }    
    # Uninstall existing version
    Start-Process -FilePath $Uninstaller -ArgumentList $Arguments
    Wait-Process -Name OneDriveSetup
    # Set OneDrive for All Users Install
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\OneDrive" -Force
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\OneDrive" -Name AllUsersInstall -PropertyType DWORD -Value 1 -Force
    Start-Process -FilePath $onedrivesetup -ArgumentList '/allusers'
    Wait-Process -Name OneDriveSetup
    New-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run' -Name OneDrive -PropertyType String -Value 'C:\Program Files\Microsoft OneDrive\OneDrive.exe /background' -Force
    Write-Host "Installed OneDrive Per-Machine"
}