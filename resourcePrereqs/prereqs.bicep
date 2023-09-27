targetScope = 'subscription'

param Location string = deployment().location

@description('The subscription id where the storage account and associated resource should be deployed.')
param SubscriptionId string = subscription().subscriptionId

@description('Optional. The custom name of the Image Gallery to Deploy.')
param CustomComputeGalleryName string = ''

@description('Optional. Whether or not to deploy a Custom Image Gallery.')
param DeployComputeGallery bool = true

@minLength(3)
@maxLength(24)
@description('The name of the storage account to deploy. Must be at least 3 characters long. Should follow CAF naming conventions.')
param StorageAccountName string = 'none'

@minLength(3)
@maxLength(11)
@description('Supply this value to automatically generate a deterministic and unique storage account name during deployment.')
param StorageAccountNamePrefix string = 'none'

@minLength(3)
@maxLength(63)
@description('Required. Blob Container Name. Must start with a letter. Can only contain lower case letters, numbers, and -.')
param BlobContainerName string

@description('Optional. Deploy Log Analytics Workspace for Monitoring the resources in this deployment.')
param DeployLogAnalytics bool = false

@description('Optional. Custom Name for the Log Analytics Workspace to create for monitoring this solution.')
param CustomLogAnalyticsWorkspaceName string = ''

@description('Optional. Resource Id of an existing Log Analytics Workspace to which diagnostic logs will be sent.')
param LogAnalyticsWorspaceResourceId string = ''

@minLength(3)
@maxLength(128)
@description('The name of the User Assigned Managed Identity that will be created and granted Storage Blob Data Reader Rights to the storage account for the Packer/Image Builder VMs.')
param ManagedIdentityName string = 'none'

@minLength(3)
@maxLength(63)
@description('The resource group name where the Storage Account will be created. It will be created if it does not exist.')
param ResourceGroupName string = 'none'

@allowed([
  'Dev'
  'Test'
  'Prod'
  ''
])
@description('The environment to which this storage account is being deployed.')
param Environment string = ''

@allowed([
  'Storage'
  'StorageV2'
  'BlobStorage'
  'FileStorage'
  'BlockBlobStorage'
])
@description('Optional. Type of Storage Account to create.')
param StorageKind string = 'StorageV2'

@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Premium_LRS'
  'Premium_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
])
@description('Optional. Storage Account Sku Name.')
param StorageSkuName string = 'Standard_LRS'

@allowed([
  'Premium'
  'Hot'
  'Cool'
])
@description('Conditional. Required if the Storage Account kind is set to BlobStorage. The access tier is used for billing. The "Premium" access tier is the default value for premium block blobs storage account type and it cannot be changed for the premium block blobs storage account type.')
param StorageAccessTier string = 'Hot'

@description('Optional. The Resource Id of the Private DNS Zone where the Private Endpoint (if configured) A record will be registered.')
param AzureBlobPrivateDnsZoneResourceId string = ''

@description('Required. Whether or not public network access is allowed for this resource. To limit public network access, use the "PermittedIPs" and/or the "ServiceEndpointSubnetResourceIds" parameters.')
@allowed([
  'Enabled'
  'Disabled'
])
param StoragePublicNetworkAccess string

@description('Optional. The ResourceId of the private endpoint subnet.')
param PrivateEndpointSubnetResourceId string = ''

@description('Optional. Array of permitted IPs or IP CIDR blocks that can access the storage account using the Public Endpoint.')
param StoragePermittedIPs array = []

@description('Optional. An array of subnet resource IDs where Service Endpoints will be created to allow access to the storage account through the public endpoint.')
param StorageServiceEndpointSubnetResourceIds array = []

@description('Optional. The tags to apply to the managed identity created by this template.')
param TagsManagedIdentities object = {}

@description('Optional. The tags to apply to the private endpoint created by this template.')
param TagsPrivateEndpoints object = {}

@description('Optional. The tags to apply to the storage account created by this template.')
param TagsStorageAccounts object = {}

@description('Optional. Indicates whether the storage account permits requests to be authorized with the account access key via Shared Key. If false, then all requests, including shared access signatures, must be authorized with Azure Active Directory (Azure AD). The default value is null, which is equivalent to true.')
param StorageAllowSharedKeyAccess bool = true

@description('Optional. The SAS expiration period. DD.HH:MM:SS.')
param StorageSASExpirationPeriod string = ''

@description('DO NOT MODIFY THIS VALUE! The timestamp is needed to differentiate deployments for certain Azure resources and must be set using a parameter.')
param Timestamp string = utcNow('yyyyMMddhhmmss')

var locations = loadJsonContent('../data/locations.json')
var ResourceAbbreviations = loadJsonContent('../data/resourceAbbreviations.json')

var resGroupName = ResourceGroupName != 'none' ? ResourceGroupName : !empty(Environment) ? '${ResourceAbbreviations.resourceGroups}-image-management-${Environment}-${locations[Location].abbreviation}' : '${ResourceAbbreviations.resourceGroups}-image-management-${locations[Location].abbreviation}'
var storageName = StorageAccountName != 'none' ? StorageAccountName : StorageAccountNamePrefix != 'none' ? '${StorageAccountNamePrefix}${guid(StorageAccountNamePrefix, resGroupName, SubscriptionId)}' : !empty(Environment) ? '${ResourceAbbreviations.storageAccounts}imageassets${Environment}${locations[Location].abbreviation}' : '${ResourceAbbreviations.storageAccounts}imageassets${locations[Location].abbreviation}'
var identityName = ManagedIdentityName != 'none' ? ManagedIdentityName : !empty(Environment) ? '${ResourceAbbreviations.userAssignedIdentities}-image-management-${Environment}-${locations[Location].abbreviation}' : '${ResourceAbbreviations.userAssignedIdentities}-image-management-${locations[Location].abbreviation}'
var blobContainerName = replace(replace(toLower(BlobContainerName), '_', '-'), ' ', '-')
var computeGalleryName = !empty(CustomComputeGalleryName) ? CustomComputeGalleryName : !empty(Environment) ? '${ResourceAbbreviations.computeGallery}-avd-${Environment}-${locations[Location].abbreviation}' : '${ResourceAbbreviations.computeGallery}-avd-${locations[Location].abbreviation}'
var logAnalyticsWorkspaceName = empty(LogAnalyticsWorspaceResourceId) ? !empty(CustomLogAnalyticsWorkspaceName) ? CustomLogAnalyticsWorkspaceName : '${ResourceAbbreviations.logAnalyticsWorkspaces}-avd-${Environment}-${locations[Location].abbreviation}' : '${ResourceAbbreviations.logAnalyticsWorkspaces}-avd-${locations[Location].abbreviation}'

var IPRules = [for IP in StoragePermittedIPs: {
  value: IP
  action: 'Allow'
}]

var VirtualNetworkRules = [for SubnetId in StorageServiceEndpointSubnetResourceIds: {
  id: SubnetId
  action: 'Allow'
}]

module resourceGroup '../carml/resources/resource-group/main.bicep' = {
  scope: subscription(SubscriptionId)
  name: 'RG-SharedServices-${Timestamp}'
  params: {
    name: resGroupName
    location: Location
  }
}

module computeGallery '../carml/compute/gallery/main.bicep' = if(DeployComputeGallery) {
  scope: az.resourceGroup(SubscriptionId, resGroupName)
  name: 'Compute-Gallery-${Timestamp}'
  params: {
    location: Location
    name: computeGalleryName
  }
}

module logAnalyticsWorkspace '../carml/operational-insights/workspace/main.bicep' = if (empty(LogAnalyticsWorspaceResourceId) && DeployLogAnalytics) {
  scope: az.resourceGroup(SubscriptionId, resGroupName)
  name: 'logAnalyticsWS-${Timestamp}'
  params: {
    location: Location
    name: logAnalyticsWorkspaceName
  }
}

module managedIdentity '../carml/managed-identity/user-assigned-identity/main.bicep' = {
  name: 'UAI-StorageAccess-${Timestamp}'
  scope: az.resourceGroup(SubscriptionId, resGroupName)
  params: {
    location: Location
    name: identityName
    tags: TagsManagedIdentities
  }
}

module storageAccount '../carml/storage/storage-account/main.bicep' = {
  name: 'StorageAccount-${Timestamp}'
  scope: az.resourceGroup(SubscriptionId, resGroupName)
  params:{
    location: Location
    name: storageName
    accessTier: StorageAccessTier
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    allowSharedKeyAccess: StorageAllowSharedKeyAccess
    blobServices: {
      automaticSnapshotPolicyEnabled: false
      containerDeleteRetentionPolicyDays: 7
      containerDeleteRetentionPolicyEnabled: true
      containers: [
        {
          name: blobContainerName
          publicAccess: 'None'
        }
      ]
      deleteRetentionPolicyEnabled: true
      deleteRetentionPolicyDays: 7
      deleteRetentionPolicyAllowPermanentDelete: true
    }
    diagnosticWorkspaceId: !empty(LogAnalyticsWorspaceResourceId) ? LogAnalyticsWorspaceResourceId : ''
    kind: StorageKind
    networkAcls: !empty(IPRules) || !(empty(StorageServiceEndpointSubnetResourceIds)) ? {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: IPRules
      virtualNetworkRules: VirtualNetworkRules
    } : {}
    privateEndpoints: !empty(PrivateEndpointSubnetResourceId) ? [
      {
        name: 'pe-${StorageAccountName}-blob-${locations[Location].abbreviation}'
        privateDnsZoneGroup: {
          privateDNSResourceIds: ['${AzureBlobPrivateDnsZoneResourceId}']
        }
        service: 'blob'
        subnetResourceId: PrivateEndpointSubnetResourceId
        tags: TagsPrivateEndpoints
      }
    ] : []
    publicNetworkAccess: StoragePublicNetworkAccess
    sasExpirationPeriod: StorageSASExpirationPeriod
    skuName: StorageSkuName
    tags: TagsStorageAccounts
  }
}

module storageBlobReaderAssignment '../carml/authorization/role-assignment/resource-group/main.bicep' = {
  name: 'roleassign-blobreader-${Timestamp}'
  scope: az.resourceGroup(SubscriptionId, resGroupName)
  params: {
    principalId: managedIdentity.outputs.principalId
    roleDefinitionIdOrName: 'Storage Blob Data Reader'
  }
}

output storageAccountResourceId string    = storageAccount.outputs.resourceId
output blobContainerName string           = blobContainerName
output managedIdentityClientId string     = managedIdentity.outputs.clientId
output managedIdentityResourceId string   = managedIdentity.outputs.resourceId

