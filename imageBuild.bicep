targetScope = 'subscription'

@description('Value to prepend to the deployment names.')
@maxLength(6)
param deploymentPrefix string = ''

@description('Value appended to the deployment names.')
param deploymentSuffix string = utcNow('yyMMddHHmm')

@description('Deployment location. Note that the compute resources will be deployed to the region where the subnet is location.')
param deploymentLocation string = deployment().location

@description('Automatically generated Image Version name.')
param autoImageVersionName string = utcNow('yy.MMdd.hhmm')

@description('The current time in ISO 8601 format. Do not modify.')
param imageVersionCreationTime string = utcNow()

param guidValue string = newGuid()

@allowed([
  'Dev'
  'Test'
  'Prod'
  ''
])
@description('Optional. The environment for which the images are being created.')
param envClassification string = ''

// Required Existing Resources
@description('Azure Compute Gallery Resource Id.')
param computeGalleryResourceId string

@description('The resource Id of the storage account containing the artifacts (scripts, installers, etc) used during the image build.')
param storageAcountResourceId string

@description('The name of the storage blob container which contains the artifacts (scripts, installers, etc) used during the image build.')
param containerName string

@description('The resource Id of the subnet to which the image build VM will be attached.')
param subnetResourceId string

@description('The resource Id of the user assigned managed identity used to access the storage account.')
param userAssignedIdentityResourceId string

@description('The resource Id of an existing resource group in which to create the vms to build the image. Leave blank to create a new resource group.')
param imageBuildResourceGroupId string = ''

// Optional Custom Naming
@description('The name of the resource group where the image build and management vms will be created.')
param customBuildResourceGroupName string = ''

// Source MarketPlace Image Properties
@description('The Marketplace Image offer')
param offer string

@description('The Marketplace Image publisher')
param publisher string

@description('The Marketplace Image sku')
param sku string

@description('The size of the Image build and Management VMs.')
param vmSize string

// Image customizers
@description('Optional. Collect image customization logs.')
param collectCustomizationLogs bool = false

@description('''Conditional. The resource id of the existing Azure storage account blob service private dns zone.
This zone must be linked to or resolvable from the vnet referenced in the [privateEndpointSubnetResourceId] parameter.''')
param blobPrivateDnsZoneResourceId string = ''

@description('Conditional. The resource id of the private endpoint subnet.')
param privateEndpointSubnetResourceId string = ''

@allowed([
  'Commercial'
  'DepartmentOfDefense'
  'GovernmentCommunityCloud'
  'GovernmentCommunityCloudHigh'
])
@description('Used to select the correct version of certain office components to install.')
param tenantType string
param installAccess bool
param installExcel bool
param installOneDriveForBusiness bool
param installOneNote bool
param installOutlook bool
param installPowerPoint bool
param installProject bool
param installpublisher bool
param installSkypeForBusiness bool
param installTeams bool
param installVirtualDesktopOptimizationTool bool
param installVisio bool
param installWord bool
param vDotInstaller string
param officeInstaller string = 'Office365-Install.zip'
param teamsInstaller string
param msrdcwebrtcsvcInstaller string
param vcRedistInstaller string
@description('''An array of image customizations consisting of the blob name and parameters.
BICEP example:
[
  {
    name: 'FSLogix'
    blobName: 'Install-FSLogix.zip'
    arguments: 'latest'
  }
  {
    name: 'VSCode'
    blobName: 'VSCode.zip'
    arguments: ''
  }
]
''')
param customizations array = []

// Output Image properties

// Optional Existing Resource
@description('The resource id of an existing Image Definition in the Compute gallery.')
param imageDefinitionResourceId string = ''

@description('Conditional. The name of the image Definition to create in the Compute Gallery. Must be provided if the [imageDefinitionResourceId] is not provided.')
param customImageDefinitionName string = ''

@description('Conditional. The computer gallery image definition Offer.')
param imageDefinitionOffer string = ''

@description('Conditional. The compute gallery image definition Publisher.')
param imageDefinitionPublisher string = ''

@description('Conditional. The compute gallery image definition Sku.')
param imageDefinitionSku string = ''

@description('Exclude the image version created by this process from the latest version for the image definition.')
param imageVersionExcludeFromLatest bool = false

@description('Optional. The number of days from now that the image version will reach end of life.')
param imageVersionEOLinDays int = 0

@sys.description('Optional. Specifies the storage account type to be used to store the image. This property is not updatable.')
@allowed([
  'Premium_LRS'
  'Standard_LRS'
  'Standard_ZRS'
])
param imageVersionStorageAccountType string = 'Standard_LRS'

@description('Optional. The regions to which the image version will be replicated in addition to the location of the deployment.')
param replicationRegions array = []

@description('The number of replicas in the primary region of the image version.')
param replicaCount int

@allowed([
  'Standard'
  'ConfidentialVM'
  'TrustedLaunch'
])
param securityType string = 'Standard'

@description('Optional. Specifies whether the network interface is accelerated networking-enabled.')
param enableAcceleratedNetworking bool = false

param imageMajorVersion int = -1
param imageMinorVersion int = -1
param imagePatch int = -1

@allowed([
  'V1'
  'V2'
])
@description('Optional. The Hyper-V generation of the image definition. (Default = "V2")')
param hyperVGeneration string = 'V2'

@description('Optional. The tags to apply to all resources deployed by this template.')
param tags object = {}

// * VARIABLE DECLARATIONS * //

var computeLocation = vnet.location
var depPrefix = '${deploymentPrefix}-'

var adminPw = '${toUpper(uniqueString(subscription().id))}-${guidValue}'
var adminUserName = 'xadmin'
var cloud = environment().name
var artifactsContainerUri = '${artifactsStorageAccount.properties.primaryEndpoints.blob}${containerName}/'

var locations = loadJsonContent('data/locations.json')
var resourceAbbreviations = loadJsonContent('data/resourceAbbreviations.json')

var collectLogs = collectCustomizationLogs && !empty(privateEndpointSubnetResourceId) && !empty(blobPrivateDnsZoneResourceId) ? true : false
var logContainerName = 'image-customization-logs'
var logContainerUri = collectLogs ? '${logsStorageAccount.outputs.primaryBlobEndpoint}${logContainerName}/' : ''
var galleryImageDefinitionPublisher = replace(imageDefinitionPublisher, ' ', '')
var galleryImageDefinitionOffer = replace(imageDefinitionOffer, ' ', '')
var galleryImageDefinitionSku = replace(imageDefinitionSku, ' ', '')

var imageBuildResourceGroupName = empty(imageBuildResourceGroupId) ? (empty(customBuildResourceGroupName) ? (!empty(envClassification) ? '${resourceAbbreviations.resourceGroups}-image-builder-${envClassification}-${locations[deploymentLocation].abbreviation}' : '${resourceAbbreviations.resourceGroups}-image-builder-${locations[deploymentLocation].abbreviation}') : customBuildResourceGroupName) : last(split(imageBuildResourceGroupId, '/'))
var imageDefinitionName = empty(imageDefinitionResourceId) ? (empty(customImageDefinitionName) ? '${replace('${resourceAbbreviations.imageDefinitions}-${replace(galleryImageDefinitionPublisher, '-', '')}-${replace(galleryImageDefinitionOffer, '-', '')}-${replace(galleryImageDefinitionSku, '-', '')}', ' ', '')}' : customImageDefinitionName) : last(split(imageDefinitionResourceId, '/'))

var imageDefinitionIsHybernateSupported = 'true'
var imageDefinitionIsAcceleratedNetworkSupported = enableAcceleratedNetworking ? 'true' : 'false'
var imageDefinitionIsHigherPerformanceSupported = false

var imageVersionName = imageMajorVersion != -1 && imageMajorVersion != -1 && imagePatch != -1 ? '${imageMajorVersion}.${imageMinorVersion}.${imagePatch}' : autoImageVersionName

var imageVersionEndOfLifeDate = imageVersionEOLinDays != 0 ? dateTimeAdd(imageVersionCreationTime, 'P${imageVersionEOLinDays}D') : ''

var targetRegions = [for region in replicationRegions: {
  excludeFromLatest: imageVersionExcludeFromLatest
  name: region
  regionalReplicaCount: replicaCount
  storageAccountType: imageVersionStorageAccountType
}]

var defReplicationRegion = [{
  excludeFromLatest: imageVersionExcludeFromLatest
  name: computeLocation
  regionalReplicaCount: replicaCount
  storageAccountType: imageVersionStorageAccountType
}]

var imageVersionTargetRegions = union(targetRegions, defReplicationRegion)

var imageVmName = take('vmimg-${uniqueString(deploymentSuffix)}', 15)
var managementVmName = take('vmmgt-${uniqueString(deploymentSuffix)}', 15)

// * RESOURCES * //

resource artifactsStorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  scope: resourceGroup(split(storageAcountResourceId, '/')[2], split(storageAcountResourceId, '/')[4])
  name: last(split(storageAcountResourceId, '/'))
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  scope: resourceGroup(split(userAssignedIdentityResourceId, '/')[2], split(userAssignedIdentityResourceId, '/')[4])
  name: last(split(userAssignedIdentityResourceId, '/'))
}

resource imageBuildRG 'Microsoft.Resources/resourceGroups@2023-07-01' = if(empty(imageBuildResourceGroupId)) {
  name: imageBuildResourceGroupName
  location: deploymentLocation
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: split(subnetResourceId, '/')[8]
  scope: resourceGroup(split(subnetResourceId, '/')[2], split(subnetResourceId, '/')[4])
}
module roleAssignment 'carml/authorization/role-assignment/resource-group/main.bicep' = {
  name: '${depPrefix}roleAssignment-uai-to-rg-${deploymentSuffix}'
  scope: resourceGroup(imageBuildRG.name)
  params: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionIdOrName: 'Virtual Machine Contributor'
  }
}

module logsStorageAccount 'carml/storage/storage-account/main.bicep' = if(collectLogs) {
  name: '${depPrefix}logsStorageAccount-${deploymentSuffix}'
  scope: resourceGroup(imageBuildRG.name)
  params: {
    name: 'logs${depPrefix}${uniqueString(subscription().id,imageBuildRG.name,depPrefix)}'
    location: computeLocation
    allowSharedKeyAccess: false
    blobServices: {
      containers: [
        {
          name: logContainerName
          publicAccess: 'None'
        }
      ]
    }
    kind: 'StorageV2'
    managementPolicyRules: [
      {
        enabled: true
        name: 'Delete Blobs after 7 days'
        type: 'Lifecycle'
        definition: {
          actions: {
            baseBlob: {
              delete: {
                daysAfterModificationGreaterThan: 7
              }
            }
          }
          filters: {
            blobTypes: [
              'blockBlob'
              'appendBlob'
            ]
          }
        }
      }
    ]
    privateEndpoints: [
      {
        name: 'pe-logs${depPrefix}${uniqueString(subscription().id,imageBuildRG.name,depPrefix)}-blob-${locations[computeLocation].abbreviation}'
        privateDnsZoneGroup: {
          privateDNSResourceIds: ['${blobPrivateDnsZoneResourceId}']
        }
        service: 'blob'
        subnetResourceId: privateEndpointSubnetResourceId
        tags: tags
      }
    ]
    publicNetworkAccess: 'Disabled'
    sasExpirationPeriod: '180.00:00:00'
    skuName: 'Standard_LRS'
    tags: tags
  }
}

module logsRoleAssignment 'carml/authorization/role-assignment/resource-group/main.bicep' = if (collectLogs) {
  name: '${depPrefix}roleassignment-blobwriter-storage-${deploymentSuffix}'
  scope: resourceGroup(imageBuildRG.name)
  params: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionIdOrName: 'Storage Blob Data Contributor'
  }  
}

module imageVm 'carml/compute/virtual-machine/main.bicep' = {
  name: 'imageVM-${deploymentSuffix}'
  scope: resourceGroup(imageBuildRG.name)
  params: {
    location: computeLocation
    name: imageVmName
    adminPassword: adminPw
    adminUsername: adminUserName
    bootDiagnostics: false
    imageReference: {
      publisher: publisher
      offer: offer
      sku: sku
      version: 'latest'
    }
    nicConfigurations: [
      {
        enabledAcceleratedNetworking: enableAcceleratedNetworking
        deleteOption: 'Delete'
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: subnetResourceId
          }
        ]
        nicSuffix: '-nic-01'
      }
    ]
    osDisk: {
      caching: 'None'
      createOption: 'fromImage'
      deleteOption: 'Delete'
      diskSizeGB: '128'
      managedDisk: {
        storageAccountType: 'Premium_LRS'
      }
    }
    osType: 'Windows'
    securityType: securityType
    tags: tags
    vTpmEnabled: true
    secureBootEnabled: true
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
    vmSize: vmSize
  }
}

module customizeImage 'modules/customizeImage.bicep' = {
  name: '${depPrefix}customizeImage-${deploymentSuffix}'
  scope: resourceGroup(imageBuildRG.name)
  params: {
    location: computeLocation
    containerName: containerName
    customizations: customizations
    installAccess:  installAccess
    installExcel: installExcel
    installOneDriveForBusiness: installOneDriveForBusiness
    installOneNote: installOneNote
    installOutlook: installOutlook
    installPowerPoint: installPowerPoint
    installProject: installProject
    installPublisher: installpublisher
    installSkypeForBusiness: installSkypeForBusiness
    installTeams: installTeams
    installVirtualDesktopOptimizationTool: installVirtualDesktopOptimizationTool
    installVisio: installVisio
    installWord: installWord
    storageAccountName: artifactsStorageAccount.name
    storageEndpoint: artifactsStorageAccount.properties.primaryEndpoints.blob
    tenantType: tenantType
    userAssignedIdentityObjectId: managedIdentity.properties.principalId
    vmName: imageVm.outputs.name
    vDotInstaller: vDotInstaller
    officeInstaller: officeInstaller
    msrdcwebrtcsvcInstaller: msrdcwebrtcsvcInstaller
    teamsInstaller: teamsInstaller
    vcRedistInstaller: vcRedistInstaller
    logBlobClientId: collectLogs ? managedIdentity.properties.clientId : ''
    logBlobContainerUri: logContainerUri
  }
}

module managementVm 'carml/compute/virtual-machine/main.bicep' = {
  name: '${depPrefix}managementVM-${deploymentSuffix}'
  scope: resourceGroup(imageBuildRG.name)
  params: {
    location: computeLocation
    name: managementVmName
    adminPassword: adminPw
    adminUsername: adminUserName
    extensionCustomScriptConfig: {
      enabled: true
      fileData: [
        {
          uri: '${artifactsContainerUri}PowerShell-Az-Module.zip'
        }
        {
          uri: '${artifactsContainerUri}cse_master_script.ps1'
        }
      ]
    }
    extensionCustomScriptProtectedSetting: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -command .\\cse_master_script.ps1'
      managedIdentity: {clientId: managedIdentity.properties.clientId}
    }

    imageReference: {
      publisher: 'MicrosoftWindowsServer'
      offer: 'WindowsServer'
      sku: '2019-datacenter-core-g2'
      version: 'latest'
    }
    nicConfigurations: [
      {
        deleteOption: 'Delete'
        ipConfigurations: [
          {
            name: 'ipconfig01'
            subnetResourceId: subnetResourceId
          }
        ]
        nicSuffix: '-nic-01'
      }
    ]
    osDisk: {
      caching: 'None'
      createOption: 'fromImage'
      deleteOption: 'Delete'
      diskSizeGB: '128'
      managedDisk: {
        storageAccountType: 'StandardSSD_LRS'
      }
    }
    osType: 'Windows'
    securityType: securityType
    secureBootEnabled: true
    tags: tags
    vTpmEnabled: true
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
    vmSize: vmSize
  }
}

module restartVM 'modules/restartVM.bicep' = {
  name: '${depPrefix}restartVM-${deploymentSuffix}'
  scope: resourceGroup(imageBuildResourceGroupName)
  params: {
    cloud: cloud
    location: computeLocation
    imageVmName: imageVm.outputs.name
    managementVmName: managementVm.outputs.name
    userAssignedIdentityResourceId: userAssignedIdentityResourceId
  }
  dependsOn: [
    customizeImage
  ]
}

module sysprepVM 'modules/sysprepVM.bicep' = {
  name: '${depPrefix}sysprepVM-${deploymentSuffix}'
  scope: resourceGroup(imageBuildResourceGroupName)
  params: {
    location: computeLocation
    vmName: imageVm.outputs.name
  }
  dependsOn: [
    restartVM
  ]
}

module generalizeVm 'modules/generalizeVM.bicep' = {
  name: '${depPrefix}generalizeVM-${deploymentSuffix}'
  scope: resourceGroup(imageBuildResourceGroupName)
  params: {
    cloud: cloud
    location: computeLocation
    imageVmName: imageVm.outputs.name
    managementVmName: managementVm.outputs.name
    userAssignedIdentityResourceId: userAssignedIdentityResourceId
  }
  dependsOn: [
    sysprepVM
  ]
}

resource existingImageDefinition 'Microsoft.Compute/galleries/images@2022-03-03' existing = if (!empty(imageDefinitionResourceId)) {
  name: last(split(imageDefinitionResourceId, '/'))
  scope: resourceGroup(split(imageDefinitionResourceId, '/')[2], split(imageDefinitionResourceId, '/')[4])  
}

module imageDefinition 'carml/compute/gallery/image/main.bicep' = if(empty(imageDefinitionResourceId)) {
  name: '${depPrefix}gallery-image-definition-${deploymentSuffix}'
  scope: resourceGroup(split(computeGalleryResourceId, '/')[2], split(computeGalleryResourceId, '/')[4])
  params: {
    location: deploymentLocation
    galleryName: last(split(computeGalleryResourceId,'/'))
    name: imageDefinitionName
    hyperVGeneration: hyperVGeneration
    isHibernateSupported: imageDefinitionIsHybernateSupported
    isAcceleratedNetworkSupported: imageDefinitionIsAcceleratedNetworkSupported
    isHigherStoragePerformanceSupported: imageDefinitionIsHigherPerformanceSupported
    securityType: securityType
    osType: 'Windows'
    osState: 'Generalized'
    publisher: galleryImageDefinitionPublisher
    offer: galleryImageDefinitionOffer
    sku: galleryImageDefinitionSku
  }
}

module imageVersion 'modules/imageVersion.bicep' = {
  name: '${depPrefix}imageVersion-${deploymentSuffix}'
  scope: resourceGroup(split(computeGalleryResourceId, '/')[2], split(computeGalleryResourceId, '/')[4])
  params: {
    location: deploymentLocation
    name: imageVersionName
    galleryName: last(split(computeGalleryResourceId, '/'))
    imageName: !empty(imageDefinitionResourceId) ? existingImageDefinition.name : imageDefinition.outputs.name
    endOfLifeDate: imageVersionEndOfLifeDate
    excludeFromLatest: imageVersionExcludeFromLatest
    replicaCount: replicaCount
    storageAccountType: imageVersionStorageAccountType
    sourceId: imageVm.outputs.resourceId
    targetRegions: imageVersionTargetRegions
    tags: {}
  }
  dependsOn: [
    generalizeVm
  ]
}

module removeVms 'modules/removeVMs.bicep' = {
  name: '${depPrefix}removeVms-${deploymentSuffix}'
  scope: resourceGroup(imageBuildResourceGroupName)
  params: {
    cloud: cloud
    location: computeLocation
    imageVmName: imageVm.outputs.name
    managementVmName: managementVm.outputs.name
    userAssignedIdentityResourceId: userAssignedIdentityResourceId
  }
  dependsOn: [
    imageVersion
  ]
}
