import { defineConfig } from "@wagmi/cli"
import { foundry } from '@wagmi/cli/plugins'

export default defineConfig(
    [
        // Poc contract abis
        {
            out: "abi/poc-abis.ts",
            plugins: [
                foundry({
                    project: './',
                    artifacts: 'out/',
                    include: [
                        'ContentRegistry.json',
                        'PaywallToken.json',
                        'CommunityToken.json',
                        'Paywall.json'
                    ]
                }),
            ],
        },
        // Campaign related contract abis
        {
            out: "abi/campaign-abis.ts",
            plugins: [
                foundry({
                    project: './',
                    artifacts: 'out/',
                    include: [
                        'NexusDiscoverCampaign.json',
                        'ReferralToken.json'
                    ]
                }),
            ],
        },
        // Kernel v2 abis
        {
            out: "abi/kernel-v2-abis.ts",
            plugins: [
                foundry({
                    project: './',
                    artifacts: 'out/',
                    include: [
                        'MultiWebAuthNRecoveryAction.json',
                        'MultiWebAuthNValidatorV2.json'
                    ]
                }),
            ],
        },
        // Kernel v3 abis
        {
            out: "abi/kernel-v3-abis.ts",
            plugins: [
                foundry({
                    project: './',
                    artifacts: 'out/',
                    include: [
                        'MultiWebAuthNValidatorV3.json'
                    ]
                }),
            ],
        },
    ]
)
