targetScope = 'resourceGroup'

param containerName string
param installAccess bool
param installExcel bool
param installOneDriveForBusiness bool
param installOneNote bool
param installOutlook bool
param installPowerPoint bool
param installProject bool
param installPublisher bool
param installSkypeForBusiness bool
param installTeams bool
param installVirtualDesktopOptimizationTool bool
param installVisio bool
param installWord bool
param location string = resourceGroup().location
param userAssignedIdentityClientId string
param logBlobContainerUri string
param storageEndpoint string
param vmName string
@allowed([
  'Commercial'
  'DepartmentOfDefense'
  'GovernmentCommunityCloud'
  'GovernmentCommunityCloudHigh'
])
param tenantType string
param customizations array
param vDotInstaller string
param officeInstaller string
param teamsInstaller string
param vcRedistInstaller string
param msrdcwebrtcsvcInstaller string
param timeStamp string = utcNow('yyMMddhhmm')

var buildDir = 'c:\\BuildDir'

var installAccessVar = '${installAccess}installAccess'
var installExcelVar = '${installExcel}installWord'
var installOneDriveForBusinessVar = '${installOneDriveForBusiness}installOneDrive'
var installOneNoteVar = '${installOneNote}installOneNote'
var installOutlookVar = '${installOutlook}installOutlook'
var installPowerPointVar = '${installPowerPoint}installPowerPoint'
var installProjectVar = '${installProject}installProject'
var installPublisherVar = '${installPublisher}installPublisher'
var installSkypeForBusinessVar = '${installSkypeForBusiness}installSkypeForBusiness'
var installVisioVar = '${installVisio}installVisio'
var installWordVar = '${installWord}installWord'

var installers = [for customization in customizations: {
  name: customization.name
  blobName: customization.blobName
  arguments: contains(customization, 'arguments') ? customization.arguments : ''
} ]

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: vmName
}

resource createBuildDir 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'create-BuildDir'
  location: location
  parent: vm
  properties: {
    treatFailureAsDeploymentFailure: true
    parameters: [
      {
        name: 'BuildDir'
        value: buildDir
      }
    ]
    source: {
      script: '''
      param(
        [string]$BuildDir
      )
      New-Item -Path $BuildDir -ItemType Directory -Force | Out-Null
      '''
    }
  }
}

@batchSize(1)
resource applications 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = [for installer in installers: {
  name: 'app-${installer.name}'
  location: location
  parent: vm
  properties: {
    treatFailureAsDeploymentFailure: true
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${installer.name}-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${installer.name}-output-${timeStamp}.log'
    parameters: [
      {
        name: 'BuildDir'
        value: buildDir
      }
      {
        name: 'userAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'ContainerName'
        value: containerName
      }
      {
        name: 'StorageEndpoint'
        value: storageEndpoint
      }
      {
        name: 'Blobname'
        value: installer.blobName
      }
      {
        name: 'Installer'
        value: installer.name
      }
      {
        name: 'Arguments'
        value: installer.arguments
      }
    ]
    source: {
      script: '''
        param(
          [string]$BuildDir,
          [string]$UserAssignedIdentityClientId,
          [string]$ContainerName,
          [string]$StorageEndpoint,
          [string]$BlobName,
          [string]$Installer,
          [string]$Arguments
        )
        If ($Arguments -eq '') {$Arguments = $null}
        $UserAssignedIdentityClientId = $UserAssignedIdentityClientId
        $ContainerName = $ContainerName
        $BlobName = $BlobName
        $StorageAccountUrl = $StorageEndpoint
        $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$StorageAccountUrl&client_id=$UserAssignedIdentityClientId"
        $AccessToken = ((Invoke-WebRequest -Headers @{Metadata=$true} -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
        $InstallDir = Join-Path $BuildDir -ChildPath $Installer
        New-Item -Path $InstallDir -ItemType Directory -Force | Out-Null
        Invoke-WebRequest -Headers @{"x-ms-version"="2017-11-09"; Authorization ="Bearer $AccessToken"} -Uri "$StorageAccountUrl$ContainerName/$BlobName" -OutFile $InstallDir\$Blobname
        Start-Sleep -Seconds 10        
        Set-Location -Path $InstallDir
        if($Blobname -like ("*.exe"))
        {
          If ($Arguments) {
            Start-Process -FilePath $InstallDir\$Blobname -ArgumentList $Arguments -NoNewWindow -Wait -PassThru
          } Else {
            Start-Process -FilePath $InstallDir\$Blobname -NoNewWindow -Wait -PassThru
          }
          $status = Get-WmiObject -Class Win32_Product | Where-Object Name -like "*$($installer)*"
          if($status)
          {
            Write-Host $status.Name "is installed"
          }
          else
          {
            Write-host $Installer "did not install properly, please check arguments"
          }
        }
        if($Blobname -like ("*.msi"))
        {
          If ($Arguments) {
            If ($Arguments -notcontains $Blobname) {$Arguments = "/i $Blobname $Arguments"}
            Start-Process -FilePath msiexec.exe -ArgumentList $Arguments -Wait
          } Else {
            Start-Process -FilePath msiexec.exe -ArgumentList "/i $BlobName /qn" -Wait
          }
          $status = Get-WmiObject -Class Win32_Product | Where-Object Name -like "*$($installer)*"
          if($status)
          {
            Write-Host $status.Name "is installed"
          }
          else
          {
            Write-host $Installer "did not install properly, please check arguments"
          }
        }
        if($Blobname -like ("*.bat"))
        {
          If ($Arguments) {
            Start-Process -FilePath cmd.exe -ArgumentList "$BlobName $Arguments" -Wait
          } Else {
            Start-Process -FilePath cmd.exe -ArgumentList "$BlobName" -Wait
          }
        }
        if($Blobname -like '*.ps1') {
          If ($Arguments) {
            & $BlobName $Arguments
          } Else {
            & $BlobName
          }
        }
        if($Blobname -like ("*.zip"))
        {
          $destinationPath = Join-Path -Path $InstallDir -ChildPath $([System.IO.Path]::GetFileNameWithoutExtension($Blobname))
          Expand-Archive -Path $InstallDir\$Blobname -DestinationPath $destinationPath -Force
          $PSScript = (Get-ChildItem -Path $destinationPath -filter '*.ps1').FullName
          If ($PSScript.count -gt 1) { $PSScript = $PSScript[0] }
          If ($Arguments) {
            & $PSScript $Arguments
          } Else {          
            & $PSScript
          }
        }
      '''
    }
  }
  dependsOn: [
    createBuildDir
  ]
}]

resource office 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if (installAccess || installExcel || installOneDriveForBusiness || installOneNote || installOutlook || installPowerPoint || installPublisher || installSkypeForBusiness || installWord || installVisio || installProject) {
  name: 'office'
  location: location
  parent: vm
  properties: {
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}Office-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}Office-output-${timeStamp}.log'
    parameters: [
      {
        name: 'BuildDir'
        value: buildDir
      }
      {
        name: 'InstallAccess'
        value: installAccessVar
      }
      {
        name: 'InstallWord'
        value: installWordVar
      }
      {
        name: 'InstallExcel'
        value: installExcelVar
      }
      {
        name: 'InstallOneDriveForBusiness'
        value: installOneDriveForBusinessVar
      }
      {
        name: 'InstallOneNote'
        value: installOneNoteVar
      }
      {
        name: 'InstallOutlook'
        value: installOutlookVar
      }
      {
        name: 'InstallPowerPoint'
        value: installPowerPointVar
      }
      {
        name: 'InstallProject'
        value: installProjectVar
      }
      {
        name: 'InstallPublisher'
        value: installPublisherVar
      }
      {
        name: 'InstallSkypeForBusiness'
        value: installSkypeForBusinessVar
      }
      {
        name: 'InstallVisio'
        value: installVisioVar
      }
      {
        name: 'userAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'ContainerName'
        value: containerName
      }
      {
        name: 'StorageEndpoint'
        value: storageEndpoint
      }
      {
        name: 'BlobName'
        value: officeInstaller
      }
    ]
    source: {
      script: '''
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
      '''
    }
  }
  dependsOn: [
    createBuildDir
    applications
  ]
}

resource teams 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if (installTeams) {
  name: 'teams'
  location: location
  parent: vm
  properties: {
    parameters: [
      {
        name: 'BuildDir'
        value: buildDir
      }
      {
        name: 'tenantType'
        value: tenantType
      }
      {
        name: 'userAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'ContainerName'
        value: containerName
      }
      {
        name: 'StorageEndpoint'
        value: storageEndpoint
      }
      {
        name: 'BlobName'
        value: teamsInstaller
      }
      {
        name: 'BlobName2'
        value: vcRedistInstaller
      }
      {
        name: 'BlobName3'
        value: msrdcwebrtcsvcInstaller
      }
    ]
    source: {
      script: '''
      param(
        [string]$tenantType,
        [string]$UserAssignedIdentityClientId,
        [string]$ContainerName,
        [string]$StorageEndpoint,
        [string]$BlobName,
        [string]$BlobName2,
        [string]$BlobName3
        )
      If($tenantType -eq "Commercial")
      {
        $TeamsUrl = "https://teams.microsoft.com/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&download=true"
      }
      If($tenantType -eq "DepartmentOfDefense")
      {
        $TeamsUrl = "https://dod.teams.microsoft.us/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&download=true"
      }
      If($tenantType -eq "GovernmentCommunityCloud")
      {
        $TeamsUrl = "https://teams.microsoft.com/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&ring=general_gcc&download=true"
      }
      If($tenantType -eq "GovernmentCommunityCloudHigh")
      {
        $TeamsUrl = "https://gov.teams.microsoft.us/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&download=true"
      }
      Write-Host $($TeamsUrl)
      $UserAssignedIdentityClientId = $UserAssignedIdentityClientId
      $ContainerName = $ContainerName
      $BlobName = $BlobName
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
      # Download & install the latest version of Microsoft Visual C++ Redistributable
      $ErrorActionPreference = "Stop"
      #$File = "$env:windir\temp\vc_redist.x64.exe"
      #Invoke-WebRequest -Uri "https://aka.ms/vs/16/release/vc_redist.x64.exe" -OutFile $File
      Start-Process -FilePath  $vcRedistFile -Args "/install /quiet /norestart /log vcdist.log" -Wait -PassThru | Out-Null
      Write-Host "Installed the latest version of Microsoft Visual C++ Redistributable"
      # Download & install the Remote Desktop WebRTC Redirector Service
      $ErrorActionPreference = "Stop"
      #$File = "$env:windir\temp\webSocketSvc.msi"
      #Invoke-WebRequest -Uri "https://aka.ms/msrdcwebrtcsvc/msi" -OutFile $File
      Start-Process -FilePath msiexec.exe -Args "/i  $webSocketFile /quiet /qn /norestart /passive /log webSocket.log" -Wait -PassThru | Out-Null
      Write-Host "Installed the Remote Desktop WebRTC Redirector Service"
      # Install Teams
      $ErrorActionPreference = "Stop"
      #$File = "$env:windir\temp\teams.msi"
      #Write-host $($TeamsUrl)
      #Invoke-WebRequest -Uri "$TeamsUrl" -OutFile $File
      $sku = (Get-ComputerInfo).OsName
      $PerMachineConfiguration = if(($Sku).Contains("multi") -eq "true"){"ALLUSER=1"}else{""}
      Start-Process -FilePath msiexec.exe -Args "/i $teamsFile /quiet /qn /norestart /passive /log teams.log $PerMachineConfiguration ALLUSERS=1" -Wait -PassThru | Out-Null
      Write-Host "Installed Teams"
      '''
    }
  }
  dependsOn: [
    createBuildDir
    applications
    office
  ]
}

resource vdot 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if (installVirtualDesktopOptimizationTool) {
  name: 'vdot'
  location: location
  parent: vm
  properties: {
    treatFailureAsDeploymentFailure: true
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}vdot-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}vdot-output-${timeStamp}.log'
    parameters: [
      {
        name: 'userAssignedIdentityClientId'
        value: userAssignedIdentityClientId
      }

      {
        name: 'ContainerName'
        value: containerName
      }
      {
        name: 'StorageEndpoint'
        value: storageEndpoint
      }
      {
        name: 'BlobName'
        value: vDotInstaller
      }
      {
        name: 'BuildDir'
        value: buildDir
      }
    ]
    source: {
      script: '''
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
      '''
    }
    timeoutInSeconds: 640
  }
  dependsOn: [
    createBuildDir
    teams
    applications
    office
  ]
}

resource removeBuildDir 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'remove-BuildDir'
  location: location
  parent: vm
  properties: {
    treatFailureAsDeploymentFailure: true
    parameters: [
      {
        name: 'BuildDir'
        value: buildDir
      }
    ]
    source: {
      script: '''
        param(
          [string]$BuildDir
        )
        Remove-Item -Path $BuildDir -Recurse -Force | Out-Null
      '''
    }
  }
  dependsOn: [
    createBuildDir
    applications
    office
    teams
    vdot
  ]
}

output tenantType string = tenantType
