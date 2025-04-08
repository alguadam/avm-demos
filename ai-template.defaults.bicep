module aiPlatform 'br/public:avm/ptn/ai-platform/baseline:0.6.5' = {
  name: 'ai-template'
  params: {
    // Required parameters
    name: 'aiplatformdef'
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

module aiServices 'br/public:avm/res/cognitive-services/account:0.10.2' = {
  name: 'ai-services'
  params: {
    // Required parameters
    kind: 'AIServices'
    name: 'aisvc-aiplatformdef'
    publicNetworkAccess: 'Enabled'
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
  }
}
