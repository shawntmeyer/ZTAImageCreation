targetScope = 'resourceGroup'

param location string = resourceGroup().location
param vmName string

resource vm 'Microsoft.Compute/virtualMachines@2022-11-01' existing = {
  name: vmName
}

resource sysprep 'Microsoft.Compute/virtualMachines/runCommands@2022-11-01' = {
  name: 'sysprep'
  location: location
  parent: vm
  properties: {
    asyncExecution: false
    parameters: []
    source: {
      script: '''
      C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown /mode:vm
      '''
    }
  }
}
