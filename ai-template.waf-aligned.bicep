var location = resourceGroup().location

/*****************DEPENDENCIES********************/
module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.11.1' = {
  name: 'log-analytics-workspace'
  params: {
    name: 'law-aiplatformwaf'
    location: location
    diagnosticSettings: [{ useThisWorkspace: true }]
  }
}

module managedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: 'managed-identity'
  params: {
    name: 'mi-aiplatformwaf'
    location: location
  }
}

//NOTE: What id the purpose if this SA?
//TODO: Make this resource waf aligned: https://github.com/Azure/bicep-registry-modules/blob/avm/res/storage/storage-account/0.19.0/avm/res/storage/storage-account/README.md#example-11-waf-aligned
module storageAccount 'br/public:avm/res/storage/storage-account:0.19.0' = {
  name: 'storage-account'
  params: {
    name: 'saaiplatformwaf'
    location: location
    // Non-required parameters
    diagnosticSettings: [{ workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId }]
    roleAssignments: [
      {
        principalId: managedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Azure AI Enterprise Network Connection Approver'
      }
    ]
  }
}

//TODO: Make this resource waf aligned: https://github.com/Azure/bicep-registry-modules/blob/avm/res/maintenance/maintenance-configuration/0.3.0/avm/res/maintenance/maintenance-configuration/README.md#example-3-waf-aligned
module maintenanceConfiguration 'br/public:avm/res/maintenance/maintenance-configuration:0.3.0' = {
  name: 'maintenance-configuration'
  params: {
    name: 'mc-aiplatformwaf'
    location: location
    extensionProperties: {
      InGuestPatchMode: 'User'
    }
    maintenanceScope: 'InGuestPatch'
    maintenanceWindow: {
      startDateTime: '2024-06-16 00:00'
      duration: '03:55'
      timeZone: 'W. Europe Standard Time'
      recurEvery: '1Day'
    }
    visibility: 'Custom'
    installPatches: {
      rebootSetting: 'IfRequired'
      windowsParameters: {
        classificationsToInclude: [
          'Critical'
          'Security'
        ]
      }
    }
  }
}

/*****************AI PLATFORM TEMPLATE********************/
//NOTE: Should vnet be out of this template so that we can add other resources to it?
module aiPlatform 'br/public:avm/ptn/ai-platform/baseline:0.6.5' = {
  name: 'ai-platform'
  params: {
    // Required parameters
    name: 'aiplatformwaf'
    // Non-required parameters
    location: location
    managedIdentityName: managedIdentity.outputs.name
    tags: {
      Env: 'test'
      'hidden-title': 'This is visible in the resource name'
    }
    virtualMachineConfiguration: {
      adminPassword: 'complexPassword123!'
      adminUsername: 'localAdminUser'
      enableAadLoginExtension: true
      enableAzureMonitorAgent: true
      maintenanceConfigurationResourceId: maintenanceConfiguration.outputs.resourceId
      patchMode: 'AutomaticByPlatform'
      zone: 1
    }
    workspaceConfiguration: {
      networkIsolationMode: 'AllowOnlyApprovedOutbound'
      networkOutboundRules: {
        rule: {
          category: 'UserDefined'
          destination: {
            serviceResourceId: storageAccount.outputs.resourceId
            subresourceTarget: 'blob'
          }
          type: 'PrivateEndpoint'
        }
      }
    }
  }
}

/*****************EXTRA SERVICES********************/
//TODO: configure/update NSG rules for the private endpoint of the AI services account
module aiServices 'br/public:avm/res/cognitive-services/account:0.10.2' = {
  name: 'accountDeployment'
  params: {
    // Required parameters
    kind: 'AIServices'
    name: 'aisvc-aiplatformwaf'
    // Non-required parameters
    customSubDomainName: 'aisvc-aiplatformwaf'
    deployments: [
      {
        name: 'gpt-4o-mini'
        model: {
          name: 'gpt-4o-mini'
          format: 'OpenAI'
          version: '2024-07-18'
        }
        sku: {
          name: 'GlobalStandard'
          capacity: 100
        }
        raiPolicyName: 'Microsoft.Default'
      }
    ]
    diagnosticSettings: [{ workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId }]
    location: location
    managedIdentities: {
      systemAssigned: true
    }
    privateEndpoints: [
      {
        //TODO: set privateDnsZoneGroup
        //TODO: re-use aiPlatform network?
        subnetResourceId: aiPlatform.outputs.virtualNetworkSubnetResourceId
      }
    ]
    sku: 'S0'
  }
}
