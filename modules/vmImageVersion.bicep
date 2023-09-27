targetScope = 'resourceGroup'
@description('Value appended to the deployment names.')
param baseTime string = utcNow('yyMMddHHmm')
param location string = resourceGroup().location
param computeGalleryResourceId string
param imageDefinitionResourceId string
param imageDefinitionName string
param imageDefinitionOffer string
param imageDefinitionPublisher string
param imageDefinitionSku string
param imageDefinitionIsAcceleratedNetworkSupported string
param imageDefinitionIsHibernateSupported string
param imageDefinitionIsHigherPerformanceSupported bool
param excludeFromLatest bool
param replicaCount int
param replicationMode string = 'Full'
param securityType string
param storageAccountType string = 'Standard_LRS'
param hyperVGeneration string
param imageVersionNumber string
param imageVmId string
param allowDeletionOfReplicatedLocations bool = true

resource gallery 'Microsoft.Compute/galleries@2022-03-03' existing = {
  name: last(split(computeGalleryResourceId, '/'))
}

resource existingVMImageDefinition 'Microsoft.Compute/galleries/images@2022-03-03' existing = if (!empty(imageDefinitionResourceId)) {
  name: last(split(imageDefinitionResourceId, '/'))
  scope: resourceGroup(split(imageDefinitionResourceId, '/')[2], split(imageDefinitionResourceId, '/')[4])  
}

module vmImageDefinition '../carml/compute/gallery/image/main.bicep' = if (empty(imageDefinitionResourceId)) {
  name: 'VMID-${imageDefinitionName}-${baseTime}'
  params: {
    location: location
    galleryName: gallery.name
    name: imageDefinitionName
    hyperVGeneration: hyperVGeneration
    isHibernateSupported: imageDefinitionIsHibernateSupported
    securityType: securityType
    isAcceleratedNetworkSupported: imageDefinitionIsAcceleratedNetworkSupported
    isHigherStoragePerformanceSupported: imageDefinitionIsHigherPerformanceSupported
    osType: 'Windows'
    osState: 'Generalized'
    publisher: imageDefinitionPublisher
    offer: imageDefinitionOffer
    sku: imageDefinitionSku
  }  
}

resource imageVersion 'Microsoft.Compute/galleries/images/versions@2022-03-03' = {
  name: imageVersionNumber
  location: location
  parent: !empty(imageDefinitionResourceId) ? existingVMImageDefinition : vmImageDefinition
  properties: {
    publishingProfile: {
      excludeFromLatest: excludeFromLatest
      replicaCount: replicaCount
      replicationMode: replicationMode
      storageAccountType: storageAccountType
      targetRegions: [
        {
          excludeFromLatest: excludeFromLatest
          name: location
          regionalReplicaCount: replicaCount
          storageAccountType: storageAccountType
        }
      ]
    }
    safetyProfile: {
      allowDeletionOfReplicatedLocations: allowDeletionOfReplicatedLocations
    }
    storageProfile: {
      source: {
        id: imageVmId
      }
    }
  }
}
