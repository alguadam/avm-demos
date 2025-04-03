module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.11.1' = {
  name: 'log-analytics-workspace-deployment'
  params: {
    name: 'octoapplawsavm'
  }
}

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.6.1' = {
  name: 'virtual-network-deployment'
  params: {
    addressPrefixes: ['10.0.0.0/8']
    name: 'octoappvnetavm'
    subnets: [
      {
        name: 'subnet001'
        addressPrefix: '10.0.0.0/24'
      }
    ]
    diagnosticSettings: [{ workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId }]
  }
}

module keyVault 'br/public:avm/res/key-vault/vault:0.12.1' = {
  name: 'key-vault-deployment'
  params: {
    name: 'octoappvaultavm'
    privateEndpoints: [{ subnetResourceId: virtualNetwork.outputs.subnetResourceIds[0] }]
    diagnosticSettings: [{ workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId }]
  }
}

module storageAccount 'br/public:avm/res/storage/storage-account:0.19.0' = {
  name: 'storage-account-deployment'
  params: {
    name: 'octoappstrgavm'
    secretsExportConfiguration: {
      accessKey1Name: 'sa-key-01'
      accessKey2Name: 'sa-key-02'
      connectionString1Name: 'sa-connection-string-01'
      connectionString2Name: 'sa-connection-string-02'
      keyVaultResourceId: keyVault.outputs.resourceId
    }
    blobServices: {
      containers: [{ name: 'container001' }]
      diagnosticSettings: [{ workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId }]
    }
    privateEndpoints: [
      {
        service: 'blob'
        subnetResourceId: virtualNetwork.outputs.subnetResourceIds[0]
      }
    ]
    diagnosticSettings: [{ workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId }]
  }
}
