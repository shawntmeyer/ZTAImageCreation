targetScope = 'subscription'

@description('Value appended to the deployment names.')
param baseTime string = utcNow('yyMMddHHmm')

@description('The current time in ISO 8601 format. Do not modify.')
param imageVersionCreationTime string = utcNow()

param guidValue string = newGuid()

@description('The location to deploy all resources in this template.')
param location string = deployment().location

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
param imageVersionExpiresInDays int = 0

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
param imageMajorVersion int
param imageMinorVersion int

@allowed([
  'V1'
  'V2'
])
@description('Optional. The Hyper-V generation of the image definition. (Default = "V2")')
param hyperVGeneration string = 'V2'

// * VARIABLE DECLARATIONS * //

var adminPw = '${toUpper(uniqueString(subscription().id))}-${guidValue}'
var adminUserName = 'xadmin'
var cloud = environment().name
var blobParentUrl = '${storageAccount.properties.primaryEndpoints.blob}${containerName}/'

var locations = loadJsonContent('data/locations.json')
var resourceAbbreviations = loadJsonContent('data/resourceAbbreviations.json')

var galleryImageDefinitionPublisher = replace(imageDefinitionPublisher, ' ', '')
var galleryImageDefinitionOffer = replace(imageDefinitionOffer, ' ', '')
var galleryImageDefinitionSku = replace(imageDefinitionSku, ' ', '')

var imageBuildResourceGroupName = !empty(customBuildResourceGroupName) ? customBuildResourceGroupName : (!empty(envClassification) ? '${resourceAbbreviations.resourceGroups}-image-builder-${envClassification}-${locations[location].abbreviation}' : '${resourceAbbreviations.resourceGroups}-image-builder-${locations[location].abbreviation}')
var imageDefinitionName = empty(imageDefinitionResourceId) ? (empty(customImageDefinitionName) ? '${replace('${resourceAbbreviations.imageDefinitions}-${galleryImageDefinitionPublisher}-${galleryImageDefinitionOffer}-${galleryImageDefinitionSku}', ' ', '')}' : customImageDefinitionName) : last(split(imageDefinitionResourceId, '/'))

var imageDefinitionIsHybernateSupported = 'true'
var imageDefinitionIsAcceleratedNetworkSupported = 'true'
var imageDefinitionIsHigherPerformanceSupported = true

var imagePatch = baseTime
var autoImageVersion ='${imageMajorVersion}.${imageMinorVersion}.${imagePatch}'
var imageVersionStorageAccountType = 'Standard_LRS'
var imageVersionEndOfLifeDate = imageVersionExpiresInDays != 0 ? dateTimeAdd(imageVersionCreationTime, 'P${imageVersionExpiresInDays}D') : ''

var targetRegions = [for region in replicationRegions: {
  excludedFromLatest: imageVersionExcludeFromLatest
  name: region
  regionalReplicaCount: replicaCount
  storageAccountType: imageVersionStorageAccountType
}]

var defReplicationRegion = [{
  excludeFromLatest: imageVersionExcludeFromLatest
  name: location
  regionalReplicaCount: replicaCount
  storageAccountType: imageVersionStorageAccountType
}]

var imageVersionTargetRegions = union(targetRegions, defReplicationRegion)

var imageVmName = take('vmimg-${uniqueString(baseTime)}', 15)
var managementVmName = take('vmmgt-${uniqueString(baseTime)}', 15)

// * RESOURCES * //

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  scope: resourceGroup(split(storageAcountResourceId, '/')[2], split(storageAcountResourceId, '/')[4])
  name: last(split(storageAcountResourceId, '/'))
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  scope: resourceGroup(split(userAssignedIdentityResourceId, '/')[2], split(userAssignedIdentityResourceId, '/')[4])
  name: last(split(userAssignedIdentityResourceId, '/'))
}

resource imageBuildRG 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: imageBuildResourceGroupName
  location: location
}

module roleAssignment 'carml/authorization/role-assignment/resource-group/main.bicep' = {
  name: 'RoleAssignment-${baseTime}'
  scope: resourceGroup(imageBuildRG.name)
  params: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionIdOrName: 'Virtual Machine Contributor'
  }
}

module imageVm 'carml/compute/virtual-machine/main.bicep' = {
  name: 'image-vm-${baseTime}'
  scope: resourceGroup(imageBuildRG.name)
  params: {
    location: location
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
    vTpmEnabled: true
    secureBootEnabled: true
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
    vmSize: vmSize
  }
}

module customizeImage 'modules/customizeImage.bicep' = {
  name: 'customize-image-${baseTime}'
  scope: resourceGroup(imageBuildRG.name)
  params: {
    location: location
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
    storageAccountName: storageAccount.name
    storageEndpoint: storageAccount.properties.primaryEndpoints.blob
    tenantType: tenantType
    userAssignedIdentityObjectId: managedIdentity.properties.principalId
    vmName: imageVm.outputs.name
    vDotInstaller: vDotInstaller
    officeInstaller: officeInstaller
    msrdcwebrtcsvcInstaller: msrdcwebrtcsvcInstaller
    teamsInstaller: teamsInstaller
    vcRedistInstaller: vcRedistInstaller
  }
}

module managementVm 'carml/compute/virtual-machine/main.bicep' = {
  name: 'management-vm-${baseTime}'
  scope: resourceGroup(imageBuildRG.name)
  params: {
    location: location
    name: managementVmName
    adminPassword: adminPw
    adminUsername: adminUserName
    extensionCustomScriptConfig: {
      enabled: true
      fileData: [
        {
          uri: '${blobParentUrl}PowerShell-Az-Module.zip'
        }
        {
          uri: '${blobParentUrl}cse_master_script.ps1'
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
    vTpmEnabled: true
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
    vmSize: vmSize
  }
}

module restartVM 'modules/restartVM.bicep' = {
  name: 'restart-vm-${baseTime}'
  scope: resourceGroup(imageBuildResourceGroupName)
  params: {
    cloud: cloud
    location: location
    imageVmName: imageVm.outputs.name
    managementVmName: managementVm.outputs.name
    userAssignedIdentityResourceId: userAssignedIdentityResourceId
  }
  dependsOn: [
    customizeImage
  ]
}

module sysprepVM 'modules/sysprepVM.bicep' = {
  name: 'sysprep-vm-${baseTime}'
  scope: resourceGroup(imageBuildResourceGroupName)
  params: {
    location: location
    vmName: imageVm.outputs.name
  }
  dependsOn: [
    restartVM
  ]
}

module generalizeVm 'modules/generalizeVM.bicep' = {
  name: 'generalize-vm-${baseTime}'
  scope: resourceGroup(imageBuildResourceGroupName)
  params: {
    cloud: cloud
    location: location
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
  name: 'gallery-image-definition-${baseTime}'
  scope: resourceGroup(split(computeGalleryResourceId, '/')[2], split(computeGalleryResourceId, '/')[4])
  params: {
    location: location
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
  name: 'ImageVersion-${baseTime}'
  scope: resourceGroup(split(computeGalleryResourceId, '/')[2], split(computeGalleryResourceId, '/')[4])
  params: {
    location: location
    name: autoImageVersion
    replicaCount: replicaCount
    galleryName: last(split(computeGalleryResourceId, '/'))
    imageName: !empty(imageDefinitionResourceId) ? existingImageDefinition.name : imageDefinition.outputs.name
    endOfLifeDate: imageVersionEndOfLifeDate
    excludeFromLatest: imageVersionExcludeFromLatest
    targetRegions: imageVersionTargetRegions
    tags: {}
    osDiskImageSourceId: imageVm.outputs.resourceId
  }
  dependsOn: [
    generalizeVm
  ]
}

module removeVms 'modules/removeVMs.bicep' = {
  name: 'remove-vm-${baseTime}'
  scope: resourceGroup(imageBuildResourceGroupName)
  params: {
    cloud: cloud
    location: location
    imageVmName: imageVm.outputs.name
    managementVmName: managementVm.outputs.name
    userAssignedIdentityResourceId: userAssignedIdentityResourceId
  }
  dependsOn: [
    imageVersion
  ]
}
