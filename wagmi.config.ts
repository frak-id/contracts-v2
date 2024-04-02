import { defineConfig } from "@wagmi/cli"
import { foundry } from '@wagmi/cli/plugins'

export default defineConfig(
    [
        // Main config
        {
            out: "abi/generated.ts",
            plugins: [
                foundry({
                    project: './',
                    artifacts: 'out/',
                    include: [
                        'ContentRegistry.json',
                        'PaywallToken.json',
                        'Paywall.json'
                    ]
                }),
            ],
        }
    ]
)
