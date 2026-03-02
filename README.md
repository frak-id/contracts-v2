# Frak - Contracts v2

This repository hosts the smart contracts related to the Nexus dApp, within the [Frak](https://frak.id/) ecosystem.

This project contains a suite of smart contracts that manage reward distribution, merchant banking, and Kernel smart wallet authentication.

## Addresses

### Frak ecosystem

Addresses of the Frak contracts, deployed on Arbitrum One and Arbitrum Sepolia.

| Name                | Address                                       |
|---------------------|-----------------------------------------------|
| RewarderHub         | `0x2832c6D07621ae8335AEBa17a5A3747f032ff168`  |
| CampaignBankFactory | `0x9aD5b5fe2b484dBa9c019660ef085FFe8A6908E1`  |
| mUSDToken           | `0x43838DCb58a61325eC5F31FD70aB8cd3540733d1`  |

### Kernel plugins

Plugins for the Kernel smart accounts.

| Name                                  | Address                                       |
|---------------------------------------|-----------------------------------------------|
| P256 Signature checker Wrapper        | `0x00e4005A00007384000000B0a8A0F300DD9fCAFA`  |
| MultiWebAuthN - Kernel v2             | `0x0000000000Fb9604350a25E826B050D859FE7b77`  |
| MultiWebAuthN Recovery - Kernel v2    | `0x000000000093c960bC9F9Dc93509E394a96c7FD9`  |

## Folder Structure

```
src
├── bank
│   ├── CampaignBank.sol
│   └── CampaignBankFactory.sol
├── constants
│   ├── Errors.sol
│   └── Roles.sol
├── kernel
│   ├── types
│   │   ├── MultiWebAuthNSignatureLib.sol
│   │   ├── SingleWebAuthNSignatureLib.sol
│   │   └── WebAuthNSignatureLib.sol
│   ├── utils
│   │   ├── P256VerifierWrapper.sol
│   │   └── WebAuthnVerifier.sol
│   └── webauthn
│       ├── MultiWebAuthNRecoveryAction.sol
│       └── MultiWebAuthNValidator.sol
├── reward
│   └── RewarderHub.sol
├── tokens
│   └── mUSDToken.sol
└── utils
    ├── BetaDistribution.sol
    └── MPT.sol
```

## Bank

The `bank/` directory contains contracts for merchant fund management within the Frak ecosystem.

### CampaignBank.sol

A multi-token bank contract that allows merchants to fund reward campaigns.

Key features:
- Each merchant has one bank that can hold multiple ERC20 tokens.
- Authorizes the RewarderHub to pull funds via ERC20 allowances.
- Bank state toggle (`isOpen`) controls operational mode:
  - When open: allowances can be updated, withdrawals are blocked.
  - When closed: allowances cannot be updated, withdrawals are allowed.
- Owner-only emergency functions to revoke allowances.
- Role-based access control for bank managers.

Important notes:
- The `isOpen` flag does NOT prevent RewarderHub from pulling funds via existing allowances.
- To fully stop fund outflow, use `revokeAllowance()` or `revokeAllowances()` to remove ERC20 approvals.

### CampaignBankFactory.sol

Factory contract for deploying CampaignBank instances.

Key features:
- Deploys minimal proxy clones of the CampaignBank implementation.
- Supports deterministic deployment via CREATE2 with salt parameter.
- Automatically configures new banks with the RewarderHub address.
- Provides address prediction for CREATE2 deployments.

## Reward

The `reward/` directory contains the central reward distribution system.

### RewarderHub.sol

Central hub for managing and distributing rewards across the Frak ecosystem.

Key features:
- Pulls funds from CampaignBank contracts via ERC20 allowances.
- Pushes rewards directly to wallet addresses.
- Batch operations for gas-efficient reward distribution.
- User freeze/compliance functionality:
  - Freeze users to prevent them from claiming rewards.
  - Recover funds from users frozen for longer than 60 days.
- Role-based access control:
  - `REWARDER_ROLE`: Can push rewards.
  - `COMPLIANCE_ROLE`: Can freeze/unfreeze users and recover frozen funds.
  - `UPGRADE_ROLE`: Can upgrade the contract (UUPS pattern).

Token compatibility:
- Does NOT support fee-on-transfer tokens.
- Does NOT support rebasing tokens.
- Only use standard ERC20 tokens that transfer the exact requested amount.

Integration:
- Works in conjunction with CampaignBank contracts to pull funds.
- Merchants deposit tokens into their CampaignBank and set allowances for the RewarderHub.
- The RewarderHub pulls tokens as rewards are distributed.

## Kernel

The `kernel/` directory contains plugins for Kernel v2 smart wallet authentication using WebAuthn/Passkeys.

### MultiWebAuthNValidator.sol

A WebAuthn validator plugin for Kernel v2 smart wallets.

Key features:
- Enables passkey-based authentication for smart accounts.
- Supports multiple passkeys per wallet (add, remove, set primary).
- Uses secp256r1 (P-256) curve for signature verification.
- Supports both RIP-7212 precompile and on-chain P256 verifier fallback.
- Compatible with browser WebAuthn APIs.

### MultiWebAuthNRecoveryAction.sol

Recovery action contract for adding passkeys to a smart account.

Key features:
- Used in conjunction with recovery mechanisms to add new passkeys.
- Delegates to MultiWebAuthNValidator for passkey addition.

### Supporting Libraries

- `WebAuthnVerifier.sol`: Core WebAuthn signature verification logic.
- `P256VerifierWrapper.sol`: Wrapper for P-256 signature verification.
- `MultiWebAuthNSignatureLib.sol`: Signature parsing for multi-passkey scenarios.
- `SingleWebAuthNSignatureLib.sol`: Signature parsing for single-passkey scenarios.
- `WebAuthNSignatureLib.sol`: Common WebAuthn signature structures.

## Tokens

The `tokens/` directory contains token contracts.

### mUSDToken.sol

A USD stablecoin token used within the Frak ecosystem.

Key features:
- Standard ERC20 implementation.
- Role-based minting via `MINTER_ROLE`.
- Deployed on mainnet for production use.

## Utils

The `utils/` directory contains utility libraries.

### BetaDistribution.sol

A library for sampling points from a Beta(2,β) probability distribution.

Key features:
- Implements Beta distribution sampling using the Gamma distribution relationship.
- Supports both integer and decimal β values via linear interpolation.
- Uses WAD (1e18) fixed-point arithmetic.
- Useful for probabilistic reward distribution mechanisms.

### MPT.sol

Merkle Patricia Trie utilities.

## Constants

The `constants/` directory contains shared constants.

### Roles.sol

Defines role constants used across the system:
- `UPGRADE_ROLE`: Permission to upgrade contracts.
- `REWARDER_ROLE`: Permission to push rewards.
- `COMPLIANCE_ROLE`: Permission to freeze/unfreeze users and recover frozen funds.

### Errors.sol

Shared error definitions.

## Development

### Build & Test

```bash
forge build                          # Build all contracts
forge test                           # Run all tests
forge test -vvv                      # Verbose output with traces
forge test --match-test test_name    # Run single test by name
forge test --match-contract Name     # Run tests in specific contract
```

### Linting & Formatting

```bash
forge fmt                            # Format all Solidity files
forge fmt --check                    # Check formatting without changes
bun run lint                         # Lint src/**/*.sol with solhint
```

### Generate ABIs

```bash
bun run generate                     # Generate TypeScript ABIs via wagmi
```
