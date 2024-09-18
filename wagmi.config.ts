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
            out: "external/abi/frak-registry-abis.ts",
            plugins: foundryPlugin([
                'ProductRegistry.json',
                'ReferralRegistry.json',
                'ProductAdministratorRegistry.json',
            ]),
        },
        // Frak interaction abis
        {
            out: "external/abi/frak-interaction-abis.ts",
            plugins: foundryPlugin([
                'ProductInteractionManager.json',
                'ProductInteractionDiamond.json',
                'PressInteractionFacet.json',
                'ReferralFeatureFacet.json',
                'DappInteractionFacet.json',
            ]),
        },
        // Frak campaign abi
        {
            out: "external/abi/frak-campaign-abis.ts",
            plugins: foundryPlugin([
                'CampaignFactory.json',
                'InteractionCampaign.json',
                'ReferralCampaign.json',
            ]),
        },
        // Frak campaign abi
        {
            out: "external/abi/stylus-abis.ts",
            plugins: foundryPlugin([
                'StylusFlattened.json',
            ]),
        },
        // Kernel v2 abis
        {
            out: "external/abi/kernel-v2-abis.ts",
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
