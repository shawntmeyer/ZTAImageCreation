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
param endOfLifeDate string = ''
param excludeFromLatest bool
param replicaCount int
param imageDefinitionSecurityType string
param targetRegions array = []
param hyperVGeneration string
param imageVersionNumber string
param imageVmId string
param allowDeletionOfReplicatedLocations bool = true

resource gallery 'Microsoft.Compute/galleries@2022-03-03' existing = {
  name: last(split(computeGalleryResourceId, '/'))
}

module vmImageDefinition '../carml/compute/gallery/image/main.bicep' = if (empty(imageDefinitionResourceId)) {
  name: 'VMID-${imageDefinitionName}-${baseTime}'
  params: {
    location: location
    galleryName: gallery.name
    name: imageDefinitionName
    hyperVGeneration: hyperVGeneration
    isHibernateSupported: imageDefinitionIsHibernateSupported
    securityType: imageDefinitionSecurityType
    isAcceleratedNetworkSupported: imageDefinitionIsAcceleratedNetworkSupported
    isHigherStoragePerformanceSupported: imageDefinitionIsHigherPerformanceSupported
    osType: 'Windows'
    osState: 'Generalized'
    publisher: imageDefinitionPublisher
    offer: imageDefinitionOffer
    sku: imageDefinitionSku
  }  
}

module vmImageVersion '../carml/compute/gallery/image/versions/main.bicep' = {
  name: 'ImageVersion-${baseTime}'
  params: {
    location: location
    name: imageVersionNumber
    replicaCount: replicaCount
    vmImageDefinitionName: !empty(imageDefinitionResourceId) ? last(split(imageDefinitionResourceId, '/')) : vmImageDefinition.outputs.name
    allowDeletionOfReplicatedLocations: allowDeletionOfReplicatedLocations
    endOfLifeDate: endOfLifeDate
    excludeFromLatest: excludeFromLatest
    targetRegions: targetRegions
    tags: {}
    osDiskImageSourceId: imageVmId
  }
}
