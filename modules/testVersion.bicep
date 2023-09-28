param location string = resourceGroup().location
var imageName = 'TestImage'
var versionName = '1.1.1'

resource image 'Microsoft.Compute/galleries/images@2022-03-03' existing = {
  name: imageName
}

resource version 'Microsoft.Compute/galleries/images/versions@2022-01-03' = {
  name: versionName
  parent: image
  location: location
}

output versionId string = version.id
