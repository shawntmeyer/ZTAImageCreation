using './imageBuild.bicep'

param deploymentLocation = deployment().location
param deploymentPrefix = ''
param timeStamp = ? /* TODO : please fix the value assigned to this parameter `utcNow()` */
param imageVersionCreationTime = ? /* TODO : please fix the value assigned to this parameter `utcNow()` */
param guidValue = ? /* TODO : please fix the value assigned to this parameter `newGuid()` */
param envClassification = ''
param computeGalleryResourceId = ''
param storageAccountResourceId = ''
param containerName = ''
param userAssignedIdentityResourceId = ''
param subnetResourceId = ''
param imageBuildResourceGroupId = ''
param customBuildResourceGroupName = ''
param customSourceImageResourceId = ''
param publisher = ''
param offer = ''
param sku = ''
param encryptionAtHost = true
param vmSize = ''
param installFsLogix = false
param fslogixBlobName = ''
param installAccess = false
param installExcel = false
param installOneDrive = false
param onedriveBlobName = ''
param installOneNote = false
param installOutlook = false
param installPowerPoint = false
param installProject = false
param installpublisher = false
param installSkypeForBusiness = false
param installVisio = false
param installWord = false
param officeBlobName = ''
param installTeams = false
param teamsBlobName = ''
param installVirtualDesktopOptimizationTool = false
param vDotBlobName = ''
param customizations = [
  {
    name: 'nx'
    blobName: 'nx.zip'
  }
  {
    name: 'fslogix'
    blobName: 'fslogix.zip'
  
  }
]
param collectCustomizationLogs = false
param installUpdates = true
param updateService = 'MU'
param wsusServer = ''
param blobPrivateDnsZoneResourceId = ''
param privateEndpointSubnetResourceId = ''
param imageDefinitionResourceId = ''
param customImageDefinitionName = ''
param imageDefinitionPublisher = ''
param imageDefinitionOffer = ''
param imageDefinitionSku = ''
param imageDefinitionIsAcceleratedNetworkSupported = false
param imageDefinitionIsHibernateSupported = false
param imageDefinitionIsHigherStoragePerformanceSupported = false
param imageDefinitionSecurityType = 'TrustedLaunchSupported'
param autoImageVersionName = ? /* TODO : please fix the value assigned to this parameter `utcNow()` */
param imageMajorVersion = -1
param imageMinorVersion = -1
param imagePatch = -1
param imageVersionEOLinDays = 0
param imageVersionDefaultReplicaCount = 1
param imageVersionDefaultStorageAccountType = 'Standard_LRS'
param imageVersionDefaultRegion = ''
param imageVersionExcludeFromLatest = false
param imageVersionTargetRegions = []
param tags = {}

