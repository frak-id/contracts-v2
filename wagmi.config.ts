import { defineConfig } from "@wagmi/cli"
import { foundry } from '@wagmi/cli/plugins'

export default defineConfig(
    [
        // Frak related abis
        {
            out: "abi/frak-abis.ts",
            plugins: [
                foundry({
                    project: './',
                    artifacts: 'out/',
                    include: [
                        // Prod stuff
                        'ContentRegistry.json',
                        'ReferralRegistry.json',
                        'ContentInteraction.json',
                        'PressInteraction.json',
                        'ContentInteractionManager.json'
                    ]
                }),
            ],
        },
        // Frak POC related abis
        {
            out: "abi/poc-abis.ts",
            plugins: [
                foundry({
                    project: './',
                    artifacts: 'out/',
                    include: [
                        'PaywallToken.json',
                        'CommunityToken.json',
                        'Paywall.json'
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
