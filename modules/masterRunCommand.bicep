param name string
param location string
param vmName string
param logBlobContainerUri string
param userAssignedIdentityClientId string
param storageAccountName string
param blobName string
param arguments string = ''
param buildDir string
param containerName string
param storageEndpoint string
param timeStamp string = utcNow('yyyyMMddmmss')


resource vm 'Microsoft.Compute/virtualMachines@2023-07-01' existing = {
  name: vmName
}

resource runCommand 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'app-${name}'
  location: location
  parent: vm
  properties: {
    treatFailureAsDeploymentFailure: true
    errorBlobManagedIdentity: empty(userAssignedIdentityClientId) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${name}-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(userAssignedIdentityClientId) ? null : {
      objectId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}${name}-output-${timeStamp}.log'
    parameters: [
      {
        name: 'BuildDir'
        value: buildDir
      }
      {
        name: 'UserAssignedIdentityClientId'
        value: userAssignedIdentityClientId
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
        value: blobName
      }
      {
        name: 'Installer'
        value: name
      }
      {
        name: 'Arguments'
        value: arguments
      }
    ]
    source: {
      script: '''
        param(
          [string]$BuildDir,
          [string]$UserAssignedIdentityClientId,
          [string]$StorageAccountName,
          [string]$ContainerName,
          [string]$StorageEndpoint,
          [string]$BlobName,
          [string]$Installer,
          [string]$Arguments
        )
        If ($Arguments -eq '') {$Arguments = $null}
        $UserAssignedIdentityObjectId = $UserAssignedIdentityObjectId
        $StorageAccountName = $StorageAccountName
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
}
