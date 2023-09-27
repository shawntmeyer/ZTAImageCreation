targetScope = 'subscription'

@description('Value appended to the deployment names.')
param baseTime string = utcNow('yyMMddHHmm')

@description('The current time in ISO 8601 format. Do not modify.')
param imageVersionCreationTime string = utcNow()

param guidValue string = newGuid()

@description('The location to deploy the VM and associated resources.')
param location string = deployment().location

@allowed([
  'Dev'
  'Test'
  'Prod'
  ''
])
@description('Optional. The environment for which the images are being created.')
param Environment string = ''

// Required Existing Resources
@description('Azure Compute Gallery Resource Id.')
param computeGalleryResourceId string

@description('The resource Id of the storage account containing the artifacts (scripts, installers, etc) used during the image build.')
param storageAcountResourceId string

@description('The name of the storage blob container which contains the artifacts (scripts, installers, etc) used during the image build.')
param containerName string

@description('The resource Id of the subnet to which the image build VM will be attached.')
param SubnetResourceId string

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
param officeInstaller string
param teamsInstaller string
param msrdcwebrtcsvcInstaller string
param vcRedistInstaller string
@description('An array of image customizations consisting of the blob name and parameters.')
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
param imageVersionExcludeFromLatest bool

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
var subscriptionId = subscription().subscriptionId
var blobParentUrl = '${storageAccount.properties.primaryEndpoints.blob}${containerName}/'

var locations = loadJsonContent('data/locations.json')
var resourceAbbreviations = loadJsonContent('data/resourceAbbreviations.json')

var imageBuildResourceGroupName = empty(customBuildResourceGroupName) ? customBuildResourceGroupName : !empty(Environment) ? '${resourceAbbreviations.resourceGroups}-image-builder-${Environment}-${locations[location].abbreviation}' : '${resourceAbbreviations.resourceGroups}-image-builder-${locations[location].abbreviation}'
var imageDefinitionName = empty(imageDefinitionResourceId) ? (empty(customImageDefinitionName) ? '${resourceAbbreviations.imageDefinitions}-${imageDefinitionPublisher}-${imageDefinitionOffer}-${imageDefinitionSku}' : customImageDefinitionName) : last(split(imageDefinitionResourceId, '/'))

var imageDefinitionIsHybernateSupported = 'true'
var imageDefinitionIsAcceleratedNetworkSupported = 'true'
var imageDefinitionIsHigherPerformanceSupported = true

var imagePatch = baseTime
var autoImageVersion ='${imageMajorVersion}.${imageMinorVersion}.${imagePatch}'
var imageVersionStorageAccountType = 'Standard_LRS'
var imageVersionEndOfLifeDate = imageVersionExpiresInDays != 0 ? dateTimeAdd(imageVersionCreationTime, 'P${imageVersionExpiresInDays}D') : ''

var allowDeletionOfReplicatedLocations = true

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

module imageBuildRG 'carml/resources/resource-group/main.bicep' = {
  name: 'ImageBuildRG-${baseTime}'
  params: {
    name: imageBuildResourceGroupName
    location: location
    roleAssignments: [
      {
          roleDefinitionIdOrName: 'Virtual Machine Contributor'
          description: 'Allows Managed Identity to manage Image VMs'
          principalIds: [
            managedIdentity.properties.principalId
          ]
      }
    ]
  }
}

module imageVm 'carml/compute/virtual-machine/main.bicep' = {
  name: 'image-vm-${baseTime}'
  scope: resourceGroup(subscriptionId, imageBuildResourceGroupName)
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
            subnetResourceId: SubnetResourceId
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
  dependsOn: [
    imageBuildRG
  ]
}

module customize 'modules/image.bicep' = {
  name: 'custom-vm-${baseTime}'
  scope: resourceGroup(subscriptionId, imageBuildResourceGroupName)
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
    vmName: imageVmName
    vDotInstaller: vDotInstaller
    officeInstaller: officeInstaller
    msrdcwebrtcsvcInstaller: msrdcwebrtcsvcInstaller
    teamsInstaller: teamsInstaller
    vcRedistInstaller: vcRedistInstaller
  }
  dependsOn: [
    imageVm
  ]
}

module managementVm 'carml/compute/virtual-machine/main.bicep' = {
  name: 'management-vm-${baseTime}'
  scope: resourceGroup(subscriptionId, imageBuildResourceGroupName)
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
            subnetResourceId: SubnetResourceId
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
  dependsOn: [
    imageBuildRG
  ]
}

module restart 'modules/restartVM.bicep' = {
  name: 'restart-vm-${baseTime}'
  scope: resourceGroup(subscriptionId, imageBuildResourceGroupName)
  params: {
    cloud: cloud
    location: location
    imageVmName: imageVm.outputs.name
    managementVmName: managementVm.outputs.name
    userAssignedIdentityResourceId: userAssignedIdentityResourceId
  }
  dependsOn: [
    customize
  ]
}

module sysprep 'modules/sysprep.bicep' = {
  name: 'sysprep-vm-${baseTime}'
  scope: resourceGroup(subscriptionId, imageBuildResourceGroupName)
  params: {
    location: location
    vmName: imageVm.outputs.name
  }
  dependsOn: [
    customize
    imageVm
    restart
    managementVm
  ]
}

module generalizeVm 'modules/generalizeVM.bicep' = {
  name: 'generalize-vm-${baseTime}'
  scope: resourceGroup(subscriptionId, imageBuildResourceGroupName)
  params: {
    cloud: cloud
    location: location
    imageVmName: imageVm.outputs.name
    managementVmName: managementVm.outputs.name
    userAssignedIdentityResourceId: userAssignedIdentityResourceId
  }
  dependsOn: [
    sysprep
  ]
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

module imageVersion 'carml/compute/gallery/image/versions/main.bicep' = {
  name: 'ImageVersion-${baseTime}'
  scope: resourceGroup(split(computeGalleryResourceId, '/')[2], split(computeGalleryResourceId, '/')[4])
  params: {
    location: location
    name: autoImageVersion
    replicaCount: replicaCount
    vmImageDefinitionName: !empty(imageDefinitionResourceId) ? last(split(imageDefinitionResourceId, '/')) : imageDefinition.outputs.name
    allowDeletionOfReplicatedLocations: allowDeletionOfReplicatedLocations
    endOfLifeDate: imageVersionEndOfLifeDate
    excludeFromLatest: imageVersionExcludeFromLatest
    targetRegions: imageVersionTargetRegions
    tags: {}
    osDiskImageSourceId: imageVm.outputs.resourceId
  }
}

module removeVms 'modules/removeVMs.bicep' = {
  name: 'remove-vm-${baseTime}'
  scope: resourceGroup(subscriptionId, imageBuildResourceGroupName)
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
