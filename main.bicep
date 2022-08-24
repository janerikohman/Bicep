param location string = 'westeurope'



var storageAccountSkuName = 'Standard_LRS'

var workspaceDataLakeAccountName =  'stjeobicep${uniqueString(resourceGroup().id)}'
var raw_workspaceDataLakeAccountName =  'stjeoraw${uniqueString(resourceGroup().id)}'
var enriched_workspaceDataLakeAccountName =  'stjeoenr${uniqueString(resourceGroup().id)}'
var synapseWorkspaceName = 'synjeobicep${uniqueString(resourceGroup().id)}'
var synapseSparkPoolName = 'sparkjeobicep'

var dataLakeStorageAccountUrl = 'https://${workspaceDataLakeAccountName}.dfs.core.windows.net'
var azureRBACStorageBlobDataContributorRoleID = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' //Storage Blob Data Contributor Role

var networkIsolationMode = 'default'

resource r_workspaceDataLakeAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: workspaceDataLakeAccountName
  location: location
  properties:{
    isHnsEnabled: true
    accessTier:'Hot'
    networkAcls: {
      defaultAction:  'Allow'
      bypass:'None'
      resourceAccessRules: [
        {
          tenantId: subscription().tenantId
          resourceId: r_synapseWorkspace.id
        }
    ]
    }
  }
  kind:'StorageV2'
  sku: {
      name: 'Standard_LRS'
  }
}

resource raw_workspaceDataLakeAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: raw_workspaceDataLakeAccountName
  location: location
  properties:{
    isHnsEnabled: true
    accessTier:'Hot'
    networkAcls: {
      defaultAction:  'Allow'
      bypass:'None'
      resourceAccessRules: [
        {
          tenantId: subscription().tenantId
          resourceId: r_synapseWorkspace.id
        }
    ]
    }
  }
  kind:'StorageV2'
  sku: {
      name: 'Standard_LRS'
  }
}

resource enriched_workspaceDataLakeAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: enriched_workspaceDataLakeAccountName
  location: location
  properties:{
    isHnsEnabled: true
    accessTier:'Hot'
    networkAcls: {
      defaultAction:  'Allow'
      bypass:'None'
      resourceAccessRules: [
        {
          tenantId: subscription().tenantId
          resourceId: r_synapseWorkspace.id
        }
    ]
    }
  }
  kind:'StorageV2'
  sku: {
      name: 'Standard_LRS'
  }
}

var privateContainerNames = [
  'sandpit'
  'synapsedefaultcontainername'
]

resource r_dataLakePrivateContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = [for containerName in privateContainerNames: {
  name:'${r_workspaceDataLakeAccount.name}/default/${containerName}'
}]

//Synapse Workspace
resource r_synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name:synapseWorkspaceName
  location: location
  identity:{
    type:'SystemAssigned'
  }
  properties:{
    defaultDataLakeStorage:{
      accountUrl: dataLakeStorageAccountUrl
      filesystem: 'synfs'
    }
    sqlAdministratorLogin: 'jeo'
    sqlAdministratorLoginPassword: 'AAA1234bbb' // TODO: User param / key vault instead!!
  }

  
  //Default Firewall Rules - Allow All Traffic
  resource r_synapseWorkspaceFirewallAllowAll 'firewallRules' = if (networkIsolationMode == 'default'){
    name: 'AllowAllNetworks'
    properties:{
      startIpAddress: '0.0.0.0'
      endIpAddress: '255.255.255.255'
    }
  }

  //Firewall Allow Azure Sevices
  //Required for Post-Deployment Scripts
  resource r_synapseWorkspaceFirewallAllowAzure 'firewallRules' = {
    name: 'AllowAllWindowsAzureIps'
    properties:{
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }

  //Set Synapse MSI as SQL Admin
  resource r_managedIdentitySqlControlSettings 'managedIdentitySqlControlSettings' = {
    name: 'default'
    properties:{
      grantSqlControlToManagedIdentity:{
        desiredState: 'Enabled'
      }
    }
  }

  //Spark Pool
  resource r_sparkPool 'bigDataPools' = {
    name: synapseSparkPoolName
    location: location
    properties:{
      autoPause:{
        enabled:true
        delayInMinutes: 15
      }
      nodeSize: 'small'
      nodeSizeFamily:'MemoryOptimized'
      sparkVersion: '2.4'
      autoScale:{
        enabled:true
        minNodeCount: 3
        maxNodeCount: 5
      }
    }
  }
}

//Synapse Workspace Role Assignment as Blob Data Contributor Role in the Data Lake Storage Account
//https://docs.microsoft.com/en-us/azure/synapse-analytics/security/how-to-grant-workspace-managed-identity-permissions
resource r_dataLakeRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(r_synapseWorkspace.name, r_workspaceDataLakeAccount.name)
  scope: r_workspaceDataLakeAccount
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACStorageBlobDataContributorRoleID)
    principalId: r_synapseWorkspace.identity.principalId
    principalType:'ServicePrincipal'
  }
}
resource rawdataLakeRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(r_synapseWorkspace.name, raw_workspaceDataLakeAccount.name)
  scope: raw_workspaceDataLakeAccount
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACStorageBlobDataContributorRoleID)
    principalId: r_synapseWorkspace.identity.principalId
    principalType:'ServicePrincipal'
  }
}
resource enricheddataLakeRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid(r_synapseWorkspace.name, enriched_workspaceDataLakeAccount.name)
  scope: enriched_workspaceDataLakeAccount
  properties:{
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', azureRBACStorageBlobDataContributorRoleID)
    principalId: r_synapseWorkspace.identity.principalId
    principalType:'ServicePrincipal'
  }
}


// output workspaceDataLakeAccountID string = r_workspaceDataLakeAccount.id
// output workspaceDataLakeAccountName string = r_workspaceDataLakeAccount.name
// output synapseWorkspaceID string = r_synapseWorkspace.id
// output synapseWorkspaceName string = r_synapseWorkspace.name
// output synapseSQLDedicatedEndpoint string = r_synapseWorkspace.properties.connectivityEndpoints.sql
// output synapseSQLServerlessEndpoint string = r_synapseWorkspace.properties.connectivityEndpoints.sqlOnDemand
// output synapseWorkspaceSparkID string = ctrlDeploySynapseSparkPool ? r_synapseWorkspace::r_sparkPool.id : ''
// output synapseWorkspaceSparkName string = ctrlDeploySynapseSparkPool ? r_synapseWorkspace::r_sparkPool.name : ''
// output synapseWorkspaceIdentityPrincipalID string = r_synapseWorkspace.identity.principalId
