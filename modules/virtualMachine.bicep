param diskEncryptionSetResourceId string
@secure()
param localAdministratorPassword string
@secure()
param localAdministratorUsername string
param location string
param marketplaceImageOffer string
param marketplaceImagePublisher string
param marketplaceImageSKU string
param sharedGalleryImageResourceId string
param sourceImageType string
param subnetResourceId string
param tags object
param userAssignedIdentityResourceId string
param virtualMachineName string
param virtualMachineSize string

var imageReference = sourceImageType == 'AzureComputeGallery' ? {
  sharedGalleryImageId: sharedGalleryImageResourceId
} : {
  publisher: marketplaceImagePublisher
  offer: marketplaceImageOffer
  sku: marketplaceImageSKU
  version: 'latest'
}

resource nic 'Microsoft.Network/networkInterfaces@2022-05-01' = {
  name: take('${virtualMachineName}-nic-${uniqueString(virtualMachineName)}', 15)
  location: location
  tags: contains(tags, 'Microsoft.Network/networkInterfaces') ? tags['Microsoft.Network/networkInterfaces'] : {}
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetResourceId
          }
        }
      }
    ]
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: virtualMachineName
  location: location
  tags: contains(tags, 'Microsoft.Compute/virtualMachines') ? tags['Microsoft.Compute/virtualMachines'] : {}
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
  }
  properties: {
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    osProfile: {
      computerName: virtualMachineName
      adminUsername: localAdministratorUsername
      adminPassword: localAdministratorPassword
    }
    storageProfile: {
      imageReference: imageReference
      osDisk: {
        createOption: 'FromImage'
        deleteOption: 'Delete'
        managedDisk: {
          diskEncryptionSet: {
            id: diskEncryptionSetResourceId
          }
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
    securityProfile: {
      encryptionAtHost: true
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
      securityType: 'TrustedLaunch'
    }
  }
}

output name string = virtualMachine.name
output resourceId string = virtualMachine.id
