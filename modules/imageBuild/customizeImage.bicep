targetScope = 'resourceGroup'

param cloud string
param location string = resourceGroup().location
param userAssignedIdentityClientId string
param logBlobContainerUri string
param storageEndpoint string
param containerName string
param managementVmName string
param imageVmName string
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

resource imageVm 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: imageVmName
}

resource managementVm 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: managementVmName
}

resource createBuildDir 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'create-BuildDir'
  location: location
  parent: imageVm
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
  name: '${installer.name}'
  location: location
  parent: imageVm
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
      script: loadTextContent('../../data/Invoke-AppInstall.ps1', 'utf-8')
    }
  }
  dependsOn: [
    createBuildDir
  ]
}]

resource office 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if (installAccess || installExcel || installOneDriveForBusiness || installOneNote || installOutlook || installPowerPoint || installPublisher || installSkypeForBusiness || installWord || installVisio || installProject) {
  name: 'office'
  location: location
  parent: imageVm
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
      script: loadTextContent('../../data/Invoke-OfficeInstall.ps1')
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
  parent: imageVm
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
      script: loadTextContent('../../data/Invoke-TeamsInstall.ps1', 'utf-8')
    }
  }
  dependsOn: [
    createBuildDir
    applications
    office
  ]
}

resource firstImageVmRestart 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'restart-vm-1'
  location: location
  parent: managementVm
  properties: {
    treatFailureAsDeploymentFailure: false
    asyncExecution: false
    parameters: [
      {
        name: 'miClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'imageVmRg'
        value: split(imageVm.id, '/')[4]
      }
      {
        name: 'imageVmName'
        value: imageVm.name
      }
      {
        name: 'Environment'
        value: cloud
      }
    ]
    source: {
      script: loadTextContent('../../data/Restart-Vm.ps1')
    }
  }
  dependsOn: [
    createBuildDir
    applications
    office
    teams
  ]
}

resource microsoftUpdates 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'install-microsoft-updates'
  location: location
  parent: imageVm
  properties: {
    asyncExecution: false
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}vdot-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
      clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}vdot-output-${timeStamp}.log'
    treatFailureAsDeploymentFailure: true
    source: {
      script: loadTextContent('../../data/Invoke-MicrosoftUpdate.ps1', 'utf-8')
    }
  }
  dependsOn: [
    firstImageVmRestart
  ]
}

resource secondImageVmRestart 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'restart-vm-2'
  location: location
  parent: managementVm
  properties: {
    treatFailureAsDeploymentFailure: false
    asyncExecution: false
    parameters: [
      {
        name: 'miClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'imageVmRg'
        value: split(imageVm.id, '/')[4]
      }
      {
        name: 'imageVmName'
        value: imageVm.name
      }
      {
        name: 'Environment'
        value: cloud
      }
    ]
    source: {
      script: loadTextContent('../../data/Restart-Vm.ps1')
    }
  }
  dependsOn: [
    microsoftUpdates
  ]
}

resource vdot 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if (installVirtualDesktopOptimizationTool) {
  name: 'vdot'
  location: location
  parent: imageVm
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
      script: loadTextContent('../../data/Invoke-VDOT.ps1')
    }
    timeoutInSeconds: 640
  }
  dependsOn: [
    secondImageVmRestart
  ]
}

resource removeBuildDir 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'remove-BuildDir'
  location: location
  parent: imageVm
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
    secondImageVmRestart
    vdot
  ]
}

resource thirdImageVmRestart 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = if (installVirtualDesktopOptimizationTool) {
  name: 'restart-vm-3'
  location: location
  parent: managementVm
  properties: {
    treatFailureAsDeploymentFailure: false
    asyncExecution: false
    parameters: [
      {
        name: 'miClientId'
        value: userAssignedIdentityClientId
      }
      {
        name: 'imageVmRg'
        value: split(imageVm.id, '/')[4]
      }
      {
        name: 'imageVmName'
        value: imageVm.name
      }
      {
        name: 'Environment'
        value: cloud
      }
    ]
    source: {
      script: loadTextContent('../../data/Restart-Vm.ps1')
    }
  }
  dependsOn: [
    removeBuildDir
  ]
}

resource sysprep 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'sysprep'
  location: location
  parent: imageVm
  properties: {
    asyncExecution: false
    errorBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
        clientId: userAssignedIdentityClientId
    }
    errorBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}MicrosoftUpdate-error-${timeStamp}.log' 
    outputBlobManagedIdentity: empty(logBlobContainerUri) ? null : {
        clientId: userAssignedIdentityClientId
    }
    outputBlobUri: empty(logBlobContainerUri) ? null : '${logBlobContainerUri}MicrosoftUpdate-output-${timeStamp}.log'
    source: {
      script: loadTextContent('../../data/Invoke-Sysprep.ps1')
    }
  }
  dependsOn: [
    removeBuildDir
    thirdImageVmRestart
  ]
}
