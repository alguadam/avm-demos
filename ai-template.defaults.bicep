module aiTemplateDefaults 'br/public:avm/ptn/ai-platform/baseline:0.6.5' = {
  name: 'aiTemplateDefaultsDeployment'
  params: {
    // Required parameters
    name: 'avmaitemplatepoc'
    // Non-required parameters
    virtualNetworkConfiguration: {
      enabled: false
    }
    bastionConfiguration: {
      enabled: false
    }
    virtualMachineConfiguration: {
      enabled: false
    }
  }
}

module aiServices 'br/public:avm/res/cognitive-services/account:<version>' = {
  name: 'accountDeployment'
  params: {
    // Required parameters
    kind: 'Face'
    name: 'csawaf001'
    // Non-required parameters
    customSubDomainName: 'xcsawaf'
    diagnosticSettings: [
      {
        eventHubAuthorizationRuleResourceId: '<eventHubAuthorizationRuleResourceId>'
        eventHubName: '<eventHubName>'
        storageAccountResourceId: '<storageAccountResourceId>'
        workspaceResourceId: '<workspaceResourceId>'
      }
    ]
    location: '<location>'
    lock: {
      kind: 'CanNotDelete'
      name: 'myCustomLockName'
    }
    managedIdentities: {
      systemAssigned: true
    }
    privateEndpoints: [
      {
        privateDnsZoneGroup: {
          privateDnsZoneGroupConfigs: [
            {
              privateDnsZoneResourceId: '<privateDnsZoneResourceId>'
            }
          ]
        }
        subnetResourceId: '<subnetResourceId>'
        tags: {
          Environment: 'Non-Prod'
          'hidden-title': 'This is visible in the resource name'
          Role: 'DeploymentValidation'
        }
      }
    ]
    sku: 'S0'
    tags: {
      Environment: 'Non-Prod'
      'hidden-title': 'This is visible in the resource name'
      Role: 'DeploymentValidation'
    }
  }
}
