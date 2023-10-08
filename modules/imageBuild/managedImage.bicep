param name string
param hyperVGeneration string
param location string = resourceGroup().location
param sourceVMResourceId string

resource image 'Microsoft.Compute/images@2023-03-01' = {
  name: name
  location: location
  properties: {
    hyperVGeneration: hyperVGeneration
    sourceVirtualMachine: {
      id: sourceVMResourceId
    }
  }
}

output resourceId string = image.id
