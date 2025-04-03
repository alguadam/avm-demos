module dependencies 'ai-template.waf-aligned.dependencies.bicep' = {
  name: 'wafDependencies'
  params: {
    storageAccountName: 'avmaitemplatewafsa'
    managedIdentityName: 'avmaitemplatewafmi'
    maintenanceConfigurationName: 'avmaitemplatewafconf'
    location: resourceGroup().location
  }
}

module baseline 'br/public:avm/ptn/ai-platform/baseline:0.6.5' = {
  name: 'baselineDeployment'
  params: {
    // Required parameters
    name: 'avmaitemplatewaf'
    // Non-required parameters
    managedIdentityName: nestedDependencies.outputs.managedIdentityName
    tags: {
      Env: 'test'
      'hidden-title': 'This is visible in the resource name'
    }
    virtualMachineConfiguration: {
      adminPassword: 'complexPassword123!'
      adminUsername: 'localAdminUser'
      enableAadLoginExtension: true
      enableAzureMonitorAgent: true
      maintenanceConfigurationResourceId: nestedDependencies.outputs.maintenanceConfigurationResourceId
      patchMode: 'AutomaticByPlatform'
      zone: 1
    }
    workspaceConfiguration: {
      networkIsolationMode: 'AllowOnlyApprovedOutbound'
      networkOutboundRules: {
        rule: {
          category: 'UserDefined'
          destination: {
            serviceResourceId: nestedDependencies.outputs.storageAccountResourceId
            subresourceTarget: 'blob'
          }
          type: 'PrivateEndpoint'
        }
      }
    }
  }
}

module account 'br/public:avm/res/cognitive-services/account:<version>' = {
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
