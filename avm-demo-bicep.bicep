resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: 'octoapplawsbicp'
  location: resourceGroup().location
  properties: {
    features: {
      searchVersion: 1
      disableLocalAuth: true
    }
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 365
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    forceCmkForQuery: true
  }
}

resource logAnalyticsWorkspaceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${logAnalyticsWorkspace.name}-diagnosticSettings'
  scope: logAnalyticsWorkspace
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'octoapppvnetbicp'
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/8'
      ]
    }
    subnets: [
      {
        name: 'subnet001'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
    ]
  }
}

resource vnetDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${virtualNetwork.name}-diagnosticSettings'
  scope: virtualNetwork
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: 'octoappvaultbicp'
  location: resourceGroup().location
  properties: {
    sku: {
      family: 'A'
      name: 'premium'
    }
    enableSoftDelete: true
    enablePurgeProtection: true
    enableRbacAuthorization: true
    tenantId: subscription().tenantId
    accessPolicies: []
    networkAcls: null
    publicNetworkAccess: 'Disabled'
  }
}

resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'pep-octoappvaultbicp-vault-0'
  location: resourceGroup().location
  properties: {
    subnet: {
      id: '${virtualNetwork.id}/subnets/subnet001'
    }
    privateLinkServiceConnections: [
      {
        name: 'keyVaultConnection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: ['vault']
        }
      }
    ]
  }
}

resource keyVaultDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${keyVault.name}-diagnosticSettings'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'octoappstrgbicp'
  location: resourceGroup().location
  sku: {
    name: 'Standard_GRS'
  }
  kind: 'StorageV2'
  properties: {
    allowSharedKeyAccess: true
    defaultToOAuthAuthentication: false
    allowCrossTenantReplication: false
    isLocalUserEnabled: false
    supportsHttpsTrafficOnly: true
    isHnsEnabled: false
    isSftpEnabled: false
    isNfsV3Enabled: false
    largeFileSharesState: 'Disabled'
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Disabled'
  }
}

resource keyVaultSecretAccessKey1 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  parent: keyVault
  name: 'sa-key-01'
  properties: {
    value: storageAccount.listKeys().keys[0].value
  }
}

resource keyVaultSecretAccessKey2 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  parent: keyVault
  name: 'sa-key-02'
  properties: {
    value: storageAccount.listKeys().keys[1].value
  }
}

resource keyVaultSecretConnectionString1 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  parent: keyVault
  name: 'sa-connection-string-01'
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
  }
}

resource keyVaultSecretConnectionString2 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
  parent: keyVault
  name: 'sa-connection-string-02'
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[1].value};EndpointSuffix=${environment().suffixes.storage}'
  }
}

resource blobStoragePrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'pep-octoappstrgbicp-blob-0'
  location: resourceGroup().location
  properties: {
    subnet: {
      id: '${virtualNetwork.id}/subnets/subnet001'
    }
    privateLinkServiceConnections: [
      {
        name: 'blobStorageConnection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: ['blob']
        }
      }
    ]
  }
}

resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${storageAccount.name}-diagnosticSettings'
  scope: storageAccount
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    containerDeleteRetentionPolicy: {
      enabled: true
    }
    deleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

resource blobContainerDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default-diagnosticSettings'
  scope: blobService
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  #disable-next-line use-parent-property
  name: '${storageAccount.name}/default/container001'
  properties: {
    publicAccess: 'None'
  }
}
