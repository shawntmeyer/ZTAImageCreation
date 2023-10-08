param(
    [string]$UserAssignedIdentityClientId,
    [string]$ContainerName,
    [string]$StorageEndpoint,
    [string]$BlobName,
    [string]$BuildDir    
  )
  $StorageAccountUrl = $StorageEndpoint
  $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$StorageAccountUrl&client_id=$UserAssignedIdentityClientId"
  $AccessToken = ((Invoke-WebRequest -Headers @{Metadata=$true} -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
  $ZIP = Join-Path -Path $BuildDir -ChildPath 'VDOT.zip'
  Invoke-WebRequest -Headers @{"x-ms-version"="2017-11-09"; Authorization ="Bearer $AccessToken"} -Uri "$StorageAccountUrl$ContainerName/$BlobName" -OutFile $ZIP
  Set-Location -Path $BuildDir
  $ErrorActionPreference = "Stop"
  Do {Start-Sleep -seconds 5} Until (Test-Path -Path $ZIP)
  Unblock-File -Path $ZIP
  $VDOTDir = Join-Path -Path $BuildDir -ChildPath 'VDOT'
  Expand-Archive -LiteralPath $ZIP -DestinationPath $VDOTDir -Force
  $Path = (Get-ChildItem -Path $VDOTDir -Recurse | Where-Object {$_.Name -eq "Windows_VDOT.ps1"}).FullName
  $Script = Get-Content -Path $Path
  $ScriptUpdate = $Script.Replace("Set-NetAdapterAdvancedProperty","#Set-NetAdapterAdvancedProperty")
  $ScriptUpdate | Set-Content -Path $Path
  & $Path -Optimizations @("AppxPackages","Autologgers","DefaultUserSettings","LGPO","NetworkOptimizations","ScheduledTasks","Services","WindowsMediaPlayer") -AdvancedOptimizations @("Edge","RemoveLegacyIE") -AcceptEULA
  Write-Output "Optimized the operating system using the Virtual Desktop Optimization Tool"