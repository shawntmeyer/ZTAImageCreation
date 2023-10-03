targetScope = 'subscription'

@description('Deployment location. Note that the compute resources will be deployed to the region where the subnet is location.')
param deploymentLocation string = deployment().location

// Required Existing Resources



// Source MarketPlace Image Properties

@description('The Marketplace Image publisher')
param publisher string

@description('The Marketplace Image offer')
param offer string

@description('The Marketplace Image sku')
param sku string


// Image customizers

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

param replicationRegions array

//

output deploymentLocation string = deploymentLocation


output publisher string = publisher

output offer string = offer

output sku string = sku

output customizations array = customizations

output replicationRegions array = replicationRegions
