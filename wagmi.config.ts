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
        // Frak registry abis
        {
            out: "abi/frak-registry-abis.ts",
            plugins: foundryPlugin([
                'ContentRegistry.json',
                'ReferralRegistry.json',
            ]),
        },
        // Frak interaction abis
        {
            out: "abi/frak-interaction-abis.ts",
            plugins: foundryPlugin([
                'ContentInteractionDiamond.json',
                'PressInteractionFacet.json',
                'ContentInteractionManager.json',
            ]),
        },
        // Frak campaign abi
        {
            out: "abi/frak-campaign-abis.ts",
            plugins: foundryPlugin([
                'InteractionCampaign.json',
                'ReferralCampaign.json',
            ]),
        },
        // Frak gating abis
        {
            out: "abi/frak-gating-abis.ts",
            plugins: foundryPlugin([
                'PaywallToken.json',
                'CommunityToken.json',
                'Paywall.json'
            ]),
        },
        // Kernel v2 abis
        {
            out: "abi/kernel-v2-abis.ts",
            plugins: foundryPlugin([
                'MultiWebAuthNRecoveryAction.json',
                'MultiWebAuthNValidatorV2.json',
                'InteractionSessionValidator.json',
                'ContentInteractionAction.json'
            ]),
        },
        // Kernel v3 abis
        {
            out: "abi/kernel-v3-abis.ts",
            plugins: foundryPlugin([
                'MultiWebAuthNValidatorV3.json'
            ]),
        },
    ]
)
