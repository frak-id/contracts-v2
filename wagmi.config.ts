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
        // Validator abis
        {
            out: "abi/kernel-abis.ts",
            plugins: [
                foundry({
                    project: './',
                    artifacts: 'out/',
                    include: [
                        'WebAuthNValidator.json',
                        'MultiWebAuthNValidatorV2.json',
                        'MultiWebAuthNValidatorV3.json'
                    ]
                }),
            ],
        },
    ]
)
