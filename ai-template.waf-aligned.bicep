var location = resourceGroup().location
var solutionPrefix = 'aiplatformwaf'

/*****************DEPENDENCIES********************/
//TODO: Make this resource waf aligned
module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.11.1' = {
  name: 'log-analytics-workspace'
  params: {
    name: '${solutionPrefix}laws'
    location: location
    diagnosticSettings: [{ useThisWorkspace: true }]
  }
}

module managedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: 'managed-identity'
  params: {
    name: '${solutionPrefix}mgid'
    location: location
  }
}

//TODO: Make this resource waf aligned: https://github.com/Azure/bicep-registry-modules/blob/avm/res/maintenance/maintenance-configuration/0.3.0/avm/res/maintenance/maintenance-configuration/README.md#example-3-waf-aligned
module maintenanceConfiguration 'br/public:avm/res/maintenance/maintenance-configuration:0.3.0' = {
  name: 'maintenance-configuration'
  params: {
    name: '${solutionPrefix}mcfg'
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

// NOTE: this NSG contains the  allowed traffic for the solution
module networkSecurityGroup_solution 'br/public:avm/res/network/network-security-group:0.5.1' = {
  name: '${uniqueString(deployment().name, location)}-nsg-solution'
  params: {
    name: '${solutionPrefix}nsgrsolt'
    location: location
    securityRules: [
      // TODO: determine what inbound and outbound rules are needed for all the solution connection AI services, website, cosmos DB, etc.
      {
        name: 'DenySshRdpOutbound'
        properties: {
          priority: 200
          access: 'Deny'
          protocol: '*'
          direction: 'Outbound'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRanges: [
            '3389'
            '22'
          ]
        }
      }
    ]
  }
}
// NOTE: this NSG contains the  allowed traffic for the solution

module networkSecurityGroup_bastion 'br/public:avm/res/network/network-security-group:0.5.1' = {
  name: '${uniqueString(deployment().name, location)}-nsg-bastion'
  params: {
    name: '${solutionPrefix}nsgrbast'
    location: location
    securityRules: [
      // TODO: add inbound and outbound rules for Azure Bastion: https://learn.microsoft.com/en-us/azure/bastion/bastion-nsg
    ]
  }
}

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.6.1' = {
  name: '${uniqueString(deployment().name, location)}-virtual-network'
  params: {
    name: '${solutionPrefix}vnet'
    location: location
    addressPrefixes: [
      '10.0.0.0/8'
    ]
    subnets: [
      {
        //NOTE: This subnet is dedicated to the deployed solutions.
        addressPrefix: '10.0.0.0/24'
        //NOTE: /24 gives 251 available IPs (Azure reserves the first four addresses and the last address, for a total of five IP addresses within each subnet: https://learn.microsoft.com/en-us/azure/virtual-network/virtual-networks-faq)
        //NOTE: determine if we need to adjust this range
        name: 'default'
        networkSecurityGroupResourceId: networkSecurityGroup_solution.outputs.resourceId
      }
      {
        //NOTE: This subnet is dedicated to Azure Bastion, which is the WAF aligned way to connected to resources deployed in the vnet.
        addressPrefix: '10.0.1.0/26'
        name: 'AzureBastionSubnet'
        //NOTE: Add NSG with rules for Azure Bastion: https://learn.microsoft.com/en-us/azure/bastion/bastion-nsg
        //networkSecurityGroupResourceId: networkSecurityGroup_bastion.outputs.resourceId
      }
    ]
  }
}

/*****************AI PLATFORM TEMPLATE********************/
//NOTE: DNS zones will resolve the Azure Services url names (e.g. blob.core.window.net) into the associated private IP
//NOTE: Check DNS zone values: https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns
var storagePrivateDnsZones = {
  'privatelink.blob.${environment().suffixes.storage}': 'blob'
  'privatelink.file.${environment().suffixes.storage}': 'file'
}

module storageAccount_privateDnsZones 'br/public:avm/res/network/private-dns-zone:0.7.0' = [
  for zone in objectKeys(storagePrivateDnsZones): {
    name: 'storage-account-private-dns-zone-${uniqueString(deployment().name, location, zone)}'
    params: {
      name: zone
      virtualNetworkLinks: [{ virtualNetworkResourceId: virtualNetwork.outputs.resourceId }]
    }
  }
]

module storageAccount 'br/public:avm/res/storage/storage-account:0.19.0' = {
  name: '${uniqueString(deployment().name, location)}-storage'
  params: {
    name: '${solutionPrefix}strg'
    location: location
    skuName: 'Standard_RAGZRS'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    defaultToOAuthAuthentication: true
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
    privateEndpoints: map(items(storagePrivateDnsZones), zone => {
      name: 'pep-${zone.value}-${solutionPrefix}'
      customNetworkInterfaceName: '${solutionPrefix}nic-${zone.value}'
      service: zone.value
      subnetResourceId: virtualNetwork.outputs.subnetResourceIds[0]
      privateDnsZoneResourceIds: [resourceId('Microsoft.Network/privateDnsZones', zone.key)]
    })
    roleAssignments: [
      {
        principalId: managedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Contributor'
        principalType: 'ServicePrincipal'
      }
      {
        principalId: managedIdentity.outputs.principalId
        roleDefinitionIdOrName: 'Storage Blob Data Contributor'
        principalType: 'ServicePrincipal'
      }
      {
        principalId: managedIdentity.outputs.principalId
        roleDefinitionIdOrName: '69566ab7-960f-475b-8e7c-b3118f30c6bd' // Storage File Data Privileged Contributor
        principalType: 'ServicePrincipal'
      }
    ]
  }
}

//NOTE: Should vnet be out of this template so that we can add other resources to it?
/* module aiPlatform 'br/public:avm/ptn/ai-platform/baseline:0.6.5' = {
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
    virtualNetworkConfiguration: {
      enabled: false
    }
  }
} */

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
        subnetResourceId: virtualNetwork.outputs.subnetResourceIds[0]
      }
    ]
    sku: 'S0'
  }
}
