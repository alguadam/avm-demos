module keyVaultAVM 'br/public:avm/res/key-vault/vault:0.12.1' = {
  name: 'deploy-key-vault'
  params: {
    name: 'kvname'
    roleAssignments: [
      {
        principalId: ''
        roleDefinitionIdOrName:'keyVault Secrets User'
      }
    ]
  }
}

module ckmAVMmodule 'br/public:avm/ptn/sa/conversation-knowledge-mining:0.1.1' = {
  name: 'deploy-ckm'
  params: {
    solutionPrefix: 'ckm'
}
}
