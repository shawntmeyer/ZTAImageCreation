param location string = resourceGroup().location

var galleryName = 'gal-images-eastus'
var imageName = 'vmid-avd-eastus'

resource gallery 'Microsoft.Compute/galleries@2022-03-03' existing = {
  name: galleryName
}

resource image 'Microsoft.Compute/galleries/images@2022-03-03' = {
  location: location
  name: imageName
  parent: gallery
  properties: {
    identifier: {
      offer: 'imageOffer'
      publisher: 'imagePublisher'
      sku: 'imageSku'
    }
    osState: 'Generalized'
    osType: 'Windows'
  }
}
