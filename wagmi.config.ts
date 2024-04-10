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
                        'ContentCommunityToken.json',
                        'CommunityTokenFactory.json',
                        'Paywall.json'
                    ]
                }),
            ],
        },
        // Validator abis
        {
            out: "abi/7579-abis.ts",
            plugins: [
                foundry({
                    project: './',
                    artifacts: 'out/',
                    include: [
                        'WebAuthNValidator.json'
                    ]
                }),
            ],
        },
    ]
)
