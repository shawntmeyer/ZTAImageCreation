targetScope = 'resourceGroup'

param location string = resourceGroup().location
param logBlobClientId string
param logBlobContainerUri string
param timeStamp string = utcNow('yyMMddhhmm')
param vmName string

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: vmName
}

resource sysprep 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'sysprep'
  location: location
  parent: vm
  properties: {
    asyncExecution: false
    errorBlobManagedIdentity: empty(logBlobClientId) ? null : {
        clientId: logBlobClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}MicrosoftUpdate-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobClientId) ? null : {
        clientId: logBlobClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}MicrosoftUpdate-output-${timeStamp}.log'
    parameters: []
    source: {
      script: '''
        Write-Output '>>> Waiting for GA Service (RdAgent) to start ...'
        while ((Get-Service RdAgent).Status -ne 'Running') { Start-Sleep -s 5 }
        Write-Output '>>> Waiting for GA Service (WindowsAzureTelemetryService) to start ...'
        while ((Get-Service WindowsAzureTelemetryService) -and ((Get-Service WindowsAzureTelemetryService).Status -ne 'Running')) { Start-Sleep -s 5 }
        Write-Output '>>> Waiting for GA Service (WindowsAzureGuestAgent) to start ...'
        while ((Get-Service WindowsAzureGuestAgent).Status -ne 'Running') { Start-Sleep -s 5 }
        if( Test-Path $Env:SystemRoot\system32\Sysprep\unattend.xml ) {
          Write-Output '>>> Removing Sysprep\unattend.xml ...'
          Remove-Item $Env:SystemRoot\system32\Sysprep\unattend.xml -Force
        }
        if (Test-Path $Env:SystemRoot\Panther\unattend.xml) {
          Write-Output '>>> Removing Panther\unattend.xml ...'
          Remove-Item $Env:SystemRoot\Panther\unattend.xml -Force
        }
        Write-Output '>>> Sysprepping VM ...'
        Start-Process -FilePath "C:\Windows\System32\Sysprep\Sysprep.exe" -ArgumentList "/generalize /oobe /quit /mode:vm" -Wait
        while($true) {
          $imageState = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State).ImageState
          Write-Output $imageState
          if ($imageState -eq 'IMAGE_STATE_GENERALIZE_RESEAL_TO_OOBE') { break }
          Start-Sleep -s 5
        }
        Write-Output '>>> Sysprep complete ...'
      '''
    }
  }
}
