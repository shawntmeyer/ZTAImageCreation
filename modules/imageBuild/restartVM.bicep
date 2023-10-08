param cloud string
param location string = resourceGroup().location
param imageVmName string
param managementVmName string
param userAssignedIdentityClientId string

resource imageVm 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: imageVmName
}

resource managementVm 'Microsoft.Compute/virtualMachines@2022-03-01' existing = {
  name: managementVmName
}

resource restartVm 'Microsoft.Compute/virtualMachines/runCommands@2023-03-01' = {
  name: 'restartVm'
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
      script: '''
        param(
          [string]$miClientId,
          [string]$imageVmRg,
          [string]$imageVmName,
          [string]$Environment
        )
        # Connect to Azure
        Connect-AzAccount -Identity -AccountId $miClientId -Environment $Environment # Run on the virtual machine
        # Restart VM
        Restart-AzVM -Name $imageVmName -ResourceGroupName $imageVmRg
    
        $lastProvisioningState = ""
        $provisioningState = (Get-AzVM -resourcegroupname $imageVmRg -name $imageVmName -Status).Statuses[1].Code
        $condition = ($provisioningState -eq "PowerState/running")
        while (!$condition) {
          if ($lastProvisioningState -ne $provisioningState) {
            write-host $imageVmName "under" $imageVmRg "is" $provisioningState "(waiting for state change)"
          }
          $lastProvisioningState = $provisioningState
    
          Start-Sleep -Seconds 5
          $provisioningState = (Get-AzVM -resourcegroupname $imageVmRg -name $imageVmName -Status).Statuses[1].Code
    
          $condition = ($provisioningState -eq "PowerState/running")
        }
        write-host $imageVmName "under" $imageVmRg "is" $provisioningState
      '''
    }
  }
}
