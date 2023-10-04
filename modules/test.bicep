param customizations array = [
  {
    name: 'FSLogix'
    blobName: 'Install-FSLogix.zip'
    arguments: 'has arguments'
  }
  {
    name: 'VSCode'
    blobName: 'VSCode.zip'
  }
]

var installers = [for item in customizations: {
  name: item.name
  blobName: item.blobName
  arguments: contains(item, 'arguments') ? item.arguments : ''
} ]

output installers array = installers
