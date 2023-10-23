metadata name = 'Authorization Locks (All scopes)'
metadata description = 'This module deploys an Authorization Lock at a Subscription or Resource Group scope.'
metadata owner = 'Azure/module-maintainers'

targetScope = 'subscription'

@allowed([
  'CanNotDelete'
  'ReadOnly'
])
@description('Required. Set lock level.')
param level string

@description('Optional. The decription attached to the lock.')
param notes string = level == 'CanNotDelete' ? 'Cannot delete resource or child resources.' : 'Cannot modify the resource or child resources.'

@description('Optional. Name of the Resource Group to assign the lock to. If Resource Group name is provided, and Subscription ID is provided, the module deploys at resource group level, therefore assigns the provided lock to the resource group.')
param resourceGroupName string = ''

@description('Optional. Subscription ID of the subscription to assign the lock to. If not provided, will use the current scope for deployment. If no resource group name is provided, the module deploys at subscription level, therefore assigns the provided locks to the subscription.')
param subscriptionId string = subscription().id

@description('Optional. Location for all resources.')
param location string = deployment().location

module lock_sub 'subscription/main.bicep' = if (!empty(subscriptionId) && empty(resourceGroupName)) {
  name: '${uniqueString(deployment().name, location)}-Lock-Sub-Module'
  scope: subscription(subscriptionId)
  params: {
    name: '${subscription().displayName}-${level}-lock'
    level: level
    notes: notes
    // owners: owners // Not intended to be applied by users (ref https://github.com/Azure/azure-cli/issues/22528)
  }
}

module lock_rg 'resource-group/main.bicep' = if (!empty(subscriptionId) && !empty(resourceGroupName)) {
  name: '${uniqueString(deployment().name, location)}-Lock-RG-Module'
  scope: resourceGroup(subscriptionId, resourceGroupName)
  params: {
    name: '${resourceGroupName}-${level}-lock'
    level: level
    notes: notes
    // owners: owners // Not intended to be applied by users (ref https://github.com/Azure/azure-cli/issues/22528)
  }
}

@description('The name of the lock.')
output name string = empty(resourceGroupName) ? lock_sub.outputs.name : lock_rg.outputs.name

@description('The resource ID of the lock.')
output resourceId string = empty(resourceGroupName) ? lock_sub.outputs.resourceId : lock_rg.outputs.resourceId

@sys.description('The scope this lock applies to.')
output scope string = empty(resourceGroupName) ? lock_sub.outputs.scope : lock_rg.outputs.scope
