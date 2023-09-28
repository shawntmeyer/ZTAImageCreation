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
param storageAccountName string
param storageEndpoint string
param vmName string
@allowed([
  'Commercial'
  'DepartmentOfDefense'
  'GovernmentCommunityCloud'
  'GovernmentCommunityCloudHigh'
])
param tenantType string
param userAssignedIdentityObjectId string
param customizations array
param vDotInstaller string
param officeInstaller string
param teamsInstaller string
param vcRedistInstaller string
param msrdcwebrtcsvcInstaller string

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

var installers = customizations

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
resource applications 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = [for installer in installers : {
  name: 'app-${installer.name}'
  location: location
  parent: vm
  properties: {
    treatFailureAsDeploymentFailure: true
    parameters: [
      {
        name: 'BuildDir'
        value: buildDir
      }
      {
        name: 'UserAssignedIdentityObjectId'
        value: userAssignedIdentityObjectId
      }
      {
        name: 'StorageAccountName'
        value: storageAccountName
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
        [string]$UserAssignedIdentityObjectId,
        [string]$StorageAccountName,
        [string]$ContainerName,
        [string]$StorageEndpoint,
        [string]$BlobName,
        [string]$Installer,
        [string]$Arguments
      )
      $UserAssignedIdentityObjectId = $UserAssignedIdentityObjectId
      $StorageAccountName = $StorageAccountName
      $ContainerName = $ContainerName
      $BlobName = $BlobName
      $StorageAccountUrl = $StorageEndpoint
      $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$StorageAccountUrl&object_id=$UserAssignedIdentityObjectId"
      $AccessToken = ((Invoke-WebRequest -Headers @{Metadata=$true} -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
      New-Item -Path $BuildDir -Name $Installer -ItemType Directory -Force | Out-Null
      Invoke-WebRequest -Headers @{"x-ms-version"="2017-11-09"; Authorization ="Bearer $AccessToken"} -Uri "$StorageAccountUrl$ContainerName/$BlobName" -OutFile $BuildDir\$Installer\$Blobname
      Start-Sleep -Seconds 10
      Set-Location -Path $BuildDir\$Installer
      if($Blobname -like ("*.exe"))
      {
        Start-Process -FilePath $BuildDir\$Installer\$Blobname -ArgumentList $Arguments -NoNewWindow -Wait -PassThru
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
        If ($Arguments -notcontains $Blobname) {$Arguments = "/i $Blobname $Arguments"}
        Start-Process -FilePath msiexec.exe -ArgumentList $Arguments -Wait
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
        Start-Process -FilePath cmd.exe -ArgumentList "$BlobName $Arguments" -Wait
      }
      if($Blobname -like ("*.ps1"))
      {
        & $BlobName $Arguments
      }
      if($Blobname -like ("*.zip"))
      {
        $destinationPath = "$BuildDir\$Installer\$($Blobname.BaseName)"
        Expand-Archive -Path $BuildDir\$Installer\$Blobname -DestinationPath $destinationPath -Force
        $PSScript = ((Get-ChildItem -Path $destinationPath -filter '*.ps1').FullName)[0]
          & $PSScript $Arguments 
      }
      '''
    }
  }
  dependsOn:[
    createBuildDir
  ]
}]

resource office 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if (installAccess || installExcel || installOneDriveForBusiness || installOneNote || installOutlook || installPowerPoint || installPublisher || installSkypeForBusiness || installWord || installVisio || installProject) {
  name: 'office'
  location: location
  parent: vm
  properties: {
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
        name: 'UserAssignedIdentityObjectId'
        value: userAssignedIdentityObjectId
      }
      {
        name: 'StorageAccountName'
        value: storageAccountName
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
        [string]$UserAssignedIdentityObjectId,
        [string]$StorageAccountName,
        [string]$ContainerName,
        [string]$StorageEndpoint,
        [string]$BlobName
      )
      $UserAssignedIdentityObjectId = $UserAssignedIdentityObjectId
      $StorageAccountName = $StorageAccountName
      $ContainerName = $ContainerName
      $BlobName = $BlobName
      $StorageAccountUrl = $StorageEndpoint
      $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$StorageAccountUrl&object_id=$UserAssignedIdentityObjectId"
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

resource vdot 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if (installVirtualDesktopOptimizationTool) {
  name: 'vdot'
  location: location
  parent: vm
  properties: {
    parameters: [
      {
        name: 'UserAssignedIdentityObjectId'
        value: userAssignedIdentityObjectId
      }
      {
        name: 'StorageAccountName'
        value: storageAccountName
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
    ]
    source: {
      script: '''
      param(
        [string]$UserAssignedIdentityObjectId,
        [string]$StorageAccountName,
        [string]$ContainerName,
        [string]$StorageEndpoint,
        [string]$BlobName
        )
        $UserAssignedIdentityObjectId = $UserAssignedIdentityObjectId
        $StorageAccountName = $StorageAccountName
        $ContainerName = $ContainerName
        $BlobName = $BlobName
        $StorageAccountUrl = $StorageEndpoint
        $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$StorageAccountUrl&object_id=$UserAssignedIdentityObjectId"
        $AccessToken = ((Invoke-WebRequest -Headers @{Metadata=$true} -Uri $TokenUri -UseBasicParsing).Content | ConvertFrom-Json).access_token
        $ZIP = "$env:windir\temp\VDOT.zip"
        Invoke-WebRequest -Headers @{"x-ms-version"="2017-11-09"; Authorization ="Bearer $AccessToken"} -Uri "$StorageAccountUrl$ContainerName/$BlobName" -OutFile $ZIP
        Start-Sleep -Seconds 30
        Set-Location -Path $env:windir\temp
        $ErrorActionPreference = "Stop"
        Unblock-File -Path $ZIP
        Expand-Archive -LiteralPath $ZIP -DestinationPath "$env:windir\temp" -Force
        $Path = (Get-ChildItem -Path "$env:windir\temp" -Recurse | Where-Object {$_.Name -eq "Windows_VDOT.ps1"}).FullName
        $Script = Get-Content -Path $Path
        $ScriptUpdate = $Script.Replace("Set-NetAdapterAdvancedProperty","#Set-NetAdapterAdvancedProperty")
        $ScriptUpdate | Set-Content -Path $Path
        & $Path -Optimizations @("AppxPackages","Autologgers","DefaultUserSettings","LGPO";"NetworkOptimizations","ScheduledTasks","Services","WindowsMediaPlayer") -AdvancedOptimizations "All" -AcceptEULA
        Write-Host "Optimized the operating system using the Virtual Desktop Optimization Tool"
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
        name: 'UserAssignedIdentityObjectId'
        value: userAssignedIdentityObjectId
      }
      {
        name: 'StorageAccountName'
        value: storageAccountName
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
        [string]$UserAssignedIdentityObjectId,
        [string]$StorageAccountName,
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
      $UserAssignedIdentityObjectId = $UserAssignedIdentityObjectId
      $StorageAccountName = $StorageAccountName
      $ContainerName = $ContainerName
      $BlobName = $BlobName
      $StorageAccountUrl = $StorageEndpoint
      $TokenUri = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$StorageAccountUrl&object_id=$UserAssignedIdentityObjectId"
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

resource microsoftUpdate 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'microsoftUpdate'
  location: location
  parent: vm
  properties: {
      asyncExecution: false
      parameters: []
      source: {
          script: '''
          param (
              # The App Name to pass to the WUA API as the calling application.
              [Parameter()]
              [String]$AppName = "Windows Update API Script",
              # The search criteria to be used.
              [Parameter()]
              [String]$Criteria = "IsInstalled=0 and Type='Software' and IsHidden=0",
              # Default service (WSUS if machine is configured to use it, or MU if opted in, or WU otherwise.)
              [Parameter()]
              [string]$Service = 'MU'
          )
          
          #region Functions
          Function Get-InstallationResultText {
              [CmdletBinding()]
              param (
                  [Parameter()]
                  [int] $Result
              )
              Switch ($Result) {
                  2 { $Text = "Succeed" }
                  3 { $Text = "Succeed with errors" }
                  4 { $Text = "Failed" }
                  5 { $Text = "Cancelled" }
                  Else { $Text = "Unexpected ($result)" }
              } 
              Return $Text
          }
          
          Function Get-DeploymentActionText {
              [CmdletBinding()]
              param (
                  [Parameter()]
                  [int]$Action
              )
              Switch ($Action) {
                  0 { $Text = "None (Inherit)" }
                  1 { $Text = "Installation" }
                  2 { $Text = "Uninstallation" }
                  3 { $Text = "Detection" }
                  4 { $Text = "Optional Installation" }
                  5 { $Text = "Unexpected ($Action)" }
              }
              Return $Text
          }
          
          function Get-UpdateDescription {
              [CmdletBinding()]
              param (
                  [Parameter()]
                  $Update
              )
              [String]$Description = $null
              [string]$Description = "$($Update.Title) {$($update.Identity.UpdateID).$($update.IdentityRevisionNumber)}"
              If ($Update.IsHidden) {
                  $Description = "$($Description) (hidden)"
              }
              If ($Script:ShowDetails) {
                  If ($update.KBArticleIDs.Count -gt 0) {
                      $Description = "$($Description)  ("
                      For ($i = 0; $i -lt $($Update.KBArticleIDs.Count); $i++) {
                          If ($i -gt 0) {
                              $Description = "$($Description), "
                          }
                          $Description = "$($Description)KB$($update.KBArticleIDs.Item[$i])"
                      }
                      $Description = "$($Description))"
                  }
                  $Description = "$($Description)  Categories: "
                  For ($i = 0; $i -lt $Update.Categories.Count; $i++) {
                      $Category = $($Update.Categories.Item[$i])
                      If ($i -gt 0) {
                          $Description = "$($Description),"
                      }
                      $Description = "$($Description) $($Category.Name) {$($Category.CategoryID)}"
                  }
                  $Description = "$($Description) Deployment action: ($(Get-DeploymentActionText -Action $($Update.DeploymentAction))"
              }
              Return $Description
          }
          #endregion functions
          
          $ExitCode = 0
          
          Switch ($Service.ToUpper()) {
              'WU' { $ServerSelection = 2 }
              'MU' { $ServerSelection = 3; $ServiceId = "7971f918-a847-4430-9279-4a52d1efe18d" }
              'WSUS' { $ServerSelection = 1 }
              'DCAT' { $ServerSelection = 3; $ServiceId = "855E8A7C-ECB4-4CA3-B045-1DFA50104289" }
              'STORE' { $serverSelection = 3; $ServiceId = "117cab2d-82b1-4b5a-a08c-4d62dbee7782" }
              Else { $ServerSelection = 3; $ServiceId = $Service }
          }
          
          If ($Service -eq 'MU') {
              $UpdateServiceManager = New-Object -ComObject Microsoft.Update.ServiceManager
              $UpdateServiceManager.ClientApplicationID = $AppName
              $UpdateServiceManager.AddService2("7971f918-a847-4430-9279-4a52d1efe18d", 7, "")
              reg.exe ADD "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AllowMUUpdateService /t REG_DWORD /d 1 /f
          }
          
          $UpdateSession = New-Object -ComObject Microsoft.Update.Session
          $updateSession.ClientApplicationID = $AppName
              
          $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
          $UpdateSearcher.ServerSelection = $ServerSelection
          If ($ServerSelection -eq 3) {
              $UpdateSearcher.ServiceId = $ServiceId
          }
          
          Write-Output "Searching for Updates..."
          
          $SearchResult = $UpdateSearcher.Search($Criteria)
          If ($SearchResult.Updates.Count -eq 0) {
              Write-Output "There are no applicable updates."
              Write-Output "Now Exiting"
              Exit $ExitCode
          }
          
          Write-Output "List of applicable items found for this computer:"
          
          For ($i = 0; $i -lt $SearchResult.Updates.Count; $i++) {
              $Update = $SearchResult.Updates.Item[$i]
              Write-Output "$($i + 1)  > $(Get-UpdateDescription -Update $Update)"
          }
          
          $AtLeastOneAdded = $false
          $ExclusiveAdded = $false   
          $UpdatesToDownload = New-Object -ComObject Microsoft.Update.UpdateColl
          Write-Output "Checking search results:"
          For ($i = 0; $i -lt $SearchResult.Updates.Count; $i++) {
              $Update = $SearchResult.Updates.Item[$i]
              $Description = Get-UpdateDescription -Update $Update
              $AddThisUpdate = $false
          
              If ($ExclusiveAdded) {
                  Write-Output "$($i + 1) > skipping: '$($Description)' because an exclusive update has already been selected."
              } Else {
                  $AddThisUpdate = $true
              }
          
              If ($AddThisUpdate) {
                  $PropertyTest = 0
                  $ErrorActionPreference = 'SilentlyContinue'
                  $PropertyTest = $Update.InstallationBehavior.Impact
                  $ErrorActionPreference = 'Stop'
                  If ($PropertyTest -eq 2) {
                      If ($AtLeastOneAdded) {
                          Write-Output "$($i + 1) > skipping: '$($Description)' because it is exclusive and other updates are being installed first."
                          $AddThisUpdate = $false
                      }
                  }
              }
          
              If ($AddThisUpdate) {
                  Write-Output "$($i + 1) > : adding '$($Description)'"
                  $UpdatesToDownload.Add($Update)
                  $AtLeastOneAdded = $true
                  $ErrorActionPreference = 'SilentlyContinue'
                  $PropertyTest = $Update.InstallationBehavior.Impact
                  $ErrorActionPreference = 'Stop'
                  If ($PropertyTest -eq 2) {
                      Write-Output "This update is exclusive; skipping remaining updates"
                      $ExclusiveAdded = $true
                  }
              }
          }
          
          $UpdatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
          Write-Output "Downloading updates..."
          $Downloader = $UpdateSession.CreateUpdateDownloader()
          $Downloader.Updates = $UpdatesToDownload
          $Downloader.Download()
          Write-Output "Succesfully downloaded updates:"
          
          For ($i = 0; $i -lt $UpdatesToDownload.Count; $i++) {
              $Update = $UpdatesToDownload.Item[$i]
              If ($Update.IsDownloaded -eq $true) {
                  Write-Output "$($i + 1) > $(Get-UpdateDescription -Update $Update)"
                  $UpdatesToInstall.Add($Update)
              }
          }
          
          If ($UpdatesToInstall.Count -gt 0) {
              $Installer = $UpdateSession.CreateUpdateInstaller()
              $Installer.Updates = $UpdatesToInstall
              $InstallationResult = $Installer.Install()
              Write-Output "Installation Result: $(Get-InstallationResultText -Result $($InstallationResult.ResultCode)) HRESULT: $($InstallationResult.GetUpdateResult[$i].HResult)"
              If ($InstallationResult.GetUpdateResult[$i].HResult -eq -2145116147) {
                  Write-Output "An updated needed additional downloaded content. Please rerun the script."
              }
          
              If ($InstallationResult.RebootRequired) {
                  $ExitCode = 1641
              }    
          }
          If ($service -eq 'MU') {
              Reg.exe DELETE "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v AllowMUUpdateService /f
          }
          Exit $ExitCode
          '''
      }
  }
  dependsOn: [
    createBuildDir
    applications
    office
    teams
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
    microsoftUpdate
  ]
}

output tenantType string = tenantType
