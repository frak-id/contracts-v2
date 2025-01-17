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
            out: "external/abi/registryAbis.ts",
            plugins: foundryPlugin([
                'ProductRegistry.json',
                'ReferralRegistry.json',
                'ProductAdministratorRegistry.json',
                'PurchaseOracle.json',
            ]),
        },
        // Frak interaction abis
        {
            out: "external/abi/interactionAbis.ts",
            plugins: foundryPlugin([
                'ProductInteractionManager.json',
                'ProductInteractionDiamond.json',
                'WebShopInteractionFacet.json',
                'PressInteractionFacet.json',
                'RetailInteractionFacet.json',
                'DappInteractionFacet.json',
                'ReferralFeatureFacet.json',
                'PurchaseFeatureFacet.json',
            ]),
        },
        // Frak campaign abi
        {
            out: "external/abi/campaignAbis.ts",
            plugins: foundryPlugin([
                'CampaignBank.json',
                'CampaignBankFactory.json',
                'CampaignFactory.json',
                'InteractionCampaign.json',
                'ReferralCampaign.json',
                'AffiliationFixedCampaign.json',
                'AffiliationRangeCampaign.json',
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
