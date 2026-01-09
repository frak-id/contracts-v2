import { defineConfig, Plugin } from "@wagmi/cli"
import { foundry, FoundryConfig } from '@wagmi/cli/plugins'

function foundryPlugin(artifacts: string[]): Plugin[] {
    return [
        foundry({
            project: './',
            artifacts: 'out/',
            include: artifacts
        })
    ]
}

export default defineConfig(
    [
        // Frak internal abi
        {
            out: "external/abi/abis.ts",
            plugins: foundryPlugin([
                'CampaignBank.json',
                'CampaignBankFactory.json',
                'RewarderHub.json',
            ]),
        },
        // Kernel v2 abis
        {
            out: "external/abi/kernelV2Abis.ts",
            plugins: foundryPlugin([
                'MultiWebAuthNRecoveryAction.json',
                'MultiWebAuthNValidatorV2.json',
                'InteractionDelegatorValidator.json',
                'InteractionDelegatorAction.json',
                'InteractionDelegator.json'
            ]),
        },
    ]
)
