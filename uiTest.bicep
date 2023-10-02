targetScope = 'subscription'

@description('Deployment location. Note that the compute resources will be deployed to the region where the subnet is location.')
param deploymentLocation string = deployment().location

@description('Value to prepend to the deployment names.')
@maxLength(6)
param deploymentPrefix string = ''

@description('Value appended to the deployment names.')
param timeStamp string = utcNow('yyMMddHHmm')

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
param storageAccountResourceId string

@description('The name of the storage blob container which contains the artifacts (scripts, installers, etc) used during the image build.')
param containerName string

@description('The resource Id of the user assigned managed identity used to access the storage account.')
param userAssignedIdentityResourceId string

@description('The resource Id of the subnet to which the image build VM will be attached.')
param subnetResourceId string

@description('The resource Id of an existing resource group in which to create the vms to build the image. Leave blank to create a new resource group.')
param imageBuildResourceGroupId string = ''

// Optional Custom Naming
@description('The custom name of the resource group where the image build and management vms will be created. Leave blank to create a new resource group based on Cloud Adoption Framework naming principals.')
param customBuildResourceGroupName string = ''

// Source MarketPlace Image Properties

@description('The Marketplace Image publisher')
param publisher string

@description('The Marketplace Image offer')
param offer string

@description('The Marketplace Image sku')
param sku string

@description('The size of the Image build and Management VMs.')
param vmSize string

@allowed([
  'Standard'
  'ConfidentialVM'
  'TrustedLaunch'
])
param securityType string = 'Standard'

@description('Optional. Specifies whether the network interface is accelerated networking-enabled.')
param enableAcceleratedNetworking bool = false

// Image customizers

@allowed([
  'Commercial'
  'DepartmentOfDefense'
  'GovernmentCommunityCloud'
  'GovernmentCommunityCloudHigh'
])
@description('Used to select the correct version of certain office components to install.')
param tenantType string = 'Commercial'
param installAccess bool = false
param installExcel bool = false
param installOneDriveForBusiness bool = false
param installOneNote bool = false
param installOutlook bool = false
param installPowerPoint bool = false
param installProject bool = false
param installpublisher bool = false
param installSkypeForBusiness bool = false
param installTeams bool = false
param installVirtualDesktopOptimizationTool bool = false
param installVisio bool = false
param installWord bool = false
param vDotInstaller string = 'VDOT'
param officeInstaller string = 'Office365-Install.zip'
param teamsInstaller string = 'teams.exe'
param msrdcwebrtcsvcInstaller string = 'string'
param vcRedistInstaller string = 'vsstudio.exe'

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

@description('Optional. Collect image customization logs.')
param collectCustomizationLogs bool = false

@description('''Conditional. The resource id of the existing Azure storage account blob service private dns zone.
Must be provided if [collectCustomizationLogs] is set to "true".
This zone must be linked to or resolvable from the vnet referenced in the [privateEndpointSubnetResourceId] parameter.''')
param blobPrivateDnsZoneResourceId string = ''

@description('Conditional. The resource id of the private endpoint subnet. Must be provided if [collectCustomizationLogs] is set to "true".')
param privateEndpointSubnetResourceId string = ''

// Output Image properties

// Optional Existing Resource
@description('Optional. The resource id of an existing Image Definition in the Compute gallery.')
param imageDefinitionResourceId string = ''

@description('''Conditional. The name of the image Definition to create in the Compute Gallery.
Only valid if [imageDefinitionResourceId] is not provided.
If left blank, the image definition name will be built on Cloud Adoption Framework principals and based on the [imageDefinitonPublisher], [imageDefinitionOffer], and [imageDefinitionSku] values.''')
param customImageDefinitionName string = ''

@description('Conditional. The compute gallery image definition Publisher.')
param imageDefinitionPublisher string = ''

@description('Conditional. The computer gallery image definition Offer.')
param imageDefinitionOffer string = ''

@description('Conditional. The compute gallery image definition Sku.')
param imageDefinitionSku string = ''

@description('Automatically generated Image Version name.')
param autoImageVersionName string = utcNow('yy.MMdd.hhmm')

@description('''Optional. The image major version from 0 - 9999.
In order to specify a custom image version you must specify the [imageMajorVersion], [imageMinorVersion], and [imagePatch] integer from 0-9999.''')
@minValue(-1)
@maxValue(9999)
param imageMajorVersion int = -1

@description('''Optional. The image minor version from 0 - 9999.
In order to specify a custom image version you must specify the [imageMajorVersion], [imageMinorVersion], and [imagePatch] integer from 0-9999.''')
@minValue(-1)
@maxValue(9999)
param imageMinorVersion int = -1

@description('''Optional. The image patch version from 0 - 9999.
In order to specify a custom image version you must specify the [imageMajorVersion], [imageMinorVersion], and [imagePatch] integer from 0-9999.''')
@minValue(-1)
@maxValue(9999)
param imagePatch int = -1

@description('Optional. The number of days from now that the image version will reach end of life.')
param imageVersionEOLinDays int = 0

@description('Exclude the image version created by this process from the latest version for the image definition.')
param imageVersionExcludeFromLatest bool = false

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

@description('Optional. The tags to apply to all resources deployed by this template.')
param tags object = {}

//

output deploymentLocation string = deploymentLocation

output deploymentPrefix string = deploymentPrefix

output envClassification string = envClassification

// Required Existing Resources
output computeGalleryResourceId string = computeGalleryResourceId

output storageAccountResourceId string = storageAccountResourceId

output containerName string = containerName

output userAssignedIdentityResourceId string = userAssignedIdentityResourceId

output subnetResourceId string = subnetResourceId

output imageBuildResourceGroupId string = imageBuildResourceGroupId

// Optional Custom Naming
output customBuildResourceGroupName string = customBuildResourceGroupName

output publisher string = publisher

output offer string = publisher

output sku string = sku

output customizations array = customizations

output collectCustomizationLogs bool = collectCustomizationLogs

output blobPrivateDnsZoneResourceId string = blobPrivateDnsZoneResourceId

output privateEndpointSubnetResourceId string = privateEndpointSubnetResourceId

output imageDefinitionResourceId string = imageDefinitionResourceId

output customImageDefinitionName string = customImageDefinitionName

output imageDefinitionPublisher string = imageDefinitionPublisher

output imageDefinitionOffer string = imageDefinitionOffer

output imageDefinitionSku string = imageDefinitionSku

output imageMajorVersion int = imageMajorVersion

output imageMinorVersion int = imageMinorVersion

output imagePatch int = imagePatch

output imageVersionEOLinDays int = imageVersionEOLinDays

output imageVersionExcludeFromLatest bool = imageVersionExcludeFromLatest

output imageVersionStorageAccountType string = imageVersionStorageAccountType

output replicationRegions array = replicationRegions

output replicaCount int = replicaCount

output tags object = tags

