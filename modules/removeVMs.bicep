param cloud string
param location string = resourceGroup().location
param imageVmName string
param managementVmName string
param userAssignedIdentityResourceId string

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  scope: resourceGroup(split(userAssignedIdentityResourceId, '/')[2], split(userAssignedIdentityResourceId, '/')[4])
  name: last(split(userAssignedIdentityResourceId, '/'))
}

resource imageVm 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: imageVmName
}

resource managementVm 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: managementVmName
}

resource removeVm 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'removeVm'
  location: location
  parent: managementVm
  properties: {
    treatFailureAsDeploymentFailure: false
    asyncExecution: true
    parameters: [
      {
        name: 'miId'
        value: managedIdentity.properties.clientId
      }
      {
        name: 'imageVmRg'
        value: split(imageVm.id, '/')[4]
      }
      {
        name: 'imageVmName'
        value: imageVmName
      }
      {
        name: 'managementVmRg'
        value: split(managementVm.id, '/')[4]
      }
      {
        name: 'managementVmName'
        value: managementVmName
      }
      {
        name: 'Environment'
        value: cloud
      }
    ]
    source: {
      script: '''
      param(
        [string]$miId,
        [string]$imageVmRg,
        [string]$imageVmName,
        [string]$managementVmRg,
        [string]$managementVmName,
        [string]$Environment
        )
        # Connect to Azure
        Connect-AzAccount -Identity -AccountId $miId -Environment $Environment # Run on the virtual machine

        # Remove Image VM and Management VM

        Remove-AzVM -Name $imageVmName -ResourceGroupName $imageVmRg -ForceDeletion $true -Force

        Remove-AzVM -Name $managementVmName -ResourceGroupName $managementVmRg -NoWait -ForceDeletion $true -Force -AsJob
      '''
    }
  }
}
