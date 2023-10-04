targetScope = 'subscription'

param computeGalleryName string
param containerName string
param deploymentNameSuffix string
param diskEncryptionSetResourceId string
param hybridUseBenefit bool
param imageDefinitionName string
@secure()
param localAdministratorPassword string
param localAdministratorUsername string
param location string
param managementVirtualMachineName string
param marketplaceImageOffer string
param marketplaceImagePublisher string
param resourceGroupName string
param subnetResourceId string
param subscriptionId string
param tags object
param userAssignedIdentityName string

module userAssignedIdentity 'userAssignedIdentity.bicep' = {
  scope: resourceGroup(subscriptionId, resourceGroupName)
  name: 'user-assigned-identity-${deploymentNameSuffix}'
  params: {
    location: location
    name: userAssignedIdentityName
    tags: tags
  }
}

module managementVM 'managementVM.bicep' = {
  name: 'management-vm-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    containerName: containerName
    diskEncryptionSetResourceId: diskEncryptionSetResourceId 
    hybridUseBenefit: hybridUseBenefit
    localAdministratorPassword: localAdministratorPassword
    localAdministratorUsername: localAdministratorUsername
    location: location
    subnetResourceId: subnetResourceId
    tags: tags
    userAssignedIdentityPrincipalId: userAssignedIdentity.outputs.principalId 
    userAssignedIdentityResourceId: userAssignedIdentity.outputs.resourceId
    virtualMachineName: managementVirtualMachineName
  }
}

module computeGallery 'computeGallery.bicep' = {
  name: 'gallery-image-${deploymentNameSuffix}'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    imageDefinitionName: imageDefinitionName
    location: location
    marketplaceImageOffer: marketplaceImageOffer
    marketplaceImagePublisher: marketplaceImagePublisher
    computeGalleryName: computeGalleryName
    tags: tags
  }
}

output userAssignedIdentityClientId string = userAssignedIdentity.outputs.clientId
output userAssignedIdentityPrincipalId string = userAssignedIdentity.outputs.principalId
output userAssignedIdentityResourceId string = userAssignedIdentity.outputs.resourceId
