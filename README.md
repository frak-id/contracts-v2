# Frak - Contracts v2

This repo hosts the smart contracts related to the Nexus dApp, inside the [Frak](https://frak.id/) ecosystem.

## Addresses

### Frak ecosystem

Address of the Frak contracts, deployed on Arbitrum and arbitrum sepolia.


| Name                      | Address                                       |
|---------------------------|-----------------------------------------------|
| Content Registry          | `0x5be7ae9f47dfe007CecA06b299e7CdAcD0A5C40e`  |
| Referral Registry         | `0x0a1d4292bC42d39e02b98A6AF9d2E49F16DBED43`  |
| Content Interaction Mgr   | `0x7A710e18a12E1C832c6f833c60e2ac389Aa14e96`  |
| FRK Paywall Token         | `0x9584A61F70cC4BEF5b8B5f588A1d35740f0C7ae2`  |
| Paywall Contract          | `0x2Ed88d7A95d687aE262A385DaB7255FA1cA39901`  |
| Community Token           | `0x581199D05d01B949c91933636EB90014cDB0168c`  | 

### Kernel plugins

Plugin for the Kernel smart accounts plugins
They can be deployed on any chain via the `deploy/` folder, using [orchestra](https://github.com/zerodevapp/orchestra)

| Name                                  | Address                                       |
|--                                     |--                                             |
| Generic                                                                               |
| P256 Signature checker Wrapper        | `0x97A24c95E317c44c0694200dd0415dD6F556663D`  |
| Kernel V3                                                                             |
| SingleWebAuthN - Kernel v3            | `0x2563cEd40Af6f51A3dF0F1b58EF4Cf1B994fDe12`  |
| MultiWebAuthN - Kernel v3             | `0x93228CA325349FC7d8C397bECc0515e370aa4555`  |
| Nexus Factory                         | `0x304bf281a28e451FbCd53FeDb0672b6021E6C40D`  |
| Recovery Policy                       | `0xD0b868A455d39be41f6f4bEb1efe3912966e8233`  |
| Recovery Contract                     | `0x518B5EFB2A2A3c1D408b8aE60A2Ba8D6d264D7BA`  |
| Kernel V2                                                                             |
| MultiWebAuthN - Kernel v2             | `0xD546c4Ba2e8e5e5c961C36e6Db0460Be03425808`  |
| MultiWebAuthN Recovery - Kernel v2    | `0x67236B8AAF4B32d2D3269e088B1d43aef7736ab9`  |


## Folder Structure

```
├─src
├── campaign
│   ├── lib/
│   ├── InteractionCampaign.sol
│   └── ReferralCampaign.sol
├── interaction
│   ├── lib/
│   ├── PressInteraction.sol
│   ├── ContentInteraction.sol
│   └── ContentInteractionManager.sol
├── registry
│   ├── ContentRegistry.sol
│   └── ReferralRegistry.sol
├── gating
│   └── Paywall.sol
├── constants
├── tokens
├── kernel
```

## Registries

### `registry/`

This directory houses contracts that function as registries for essential data within the Frak ecosystem. 

#### `ContentRegistry.sol`

- Manages metadata associated with content within the Frak ecosystem.
- Each content piece is represented by an ERC-721 token and is identified by a unique domain.
- Stores content metadata: name, domain, and supported content types.
- Handles content registration, metadata updates, ownership transfers, and content discovery.

#### `ReferralRegistry.sol`

- Manages referral trees for implementing referral programs and reward distributions.
- Allows creation of referral trees, each identified by a unique `bytes32` selector.
- Tracks referrals within each tree, establishing relationships between referrers and referees.
- Controls write access to referral trees to ensure only authorized contracts or users can add new referrals.

## Interactions

### `interaction/`

This directory contains contracts that facilitate interactions between users and content within the Frak ecosystem. 

#### `ContentInteractionManager.sol`

- Acts as a factory and registry for `ContentInteraction` contracts.
- **Responsibilities:**
    - Deploys new interaction contracts for specific content types on demand.
    - Maintains a mapping between content types and their corresponding interaction contracts.
    - Allows retrieval of the appropriate interaction contract for a given content.

#### `ContentInteraction.sol`

- Abstract base contract that defines the interface for user interactions with content.
- **Key Features:**
    - Provides an abstract framework for handling user interactions, allowing for customization in derived contracts.
    - Associates each `ContentInteraction` contract with a specific content ID for accurate tracking.
    - Includes logic for:
        - Validating user interactions using EIP-712 signatures to prevent unauthorized actions.
        - Managing referral relationships with the `ReferralRegistry`.
        - Interacting with `InteractionCampaign` contracts to trigger reward distributions.

#### `PressInteraction.sol`

- A concrete implementation of the `ContentInteraction` contract specifically designed for press articles.
- **Functionality:**
    - Tracks user interactions with press articles, such as article opens, reads, and share link creation.
    - Emits events for each interaction type, providing a record of user engagement.
    - Emit press related interaction for potential linked Campaign.

## Campaigns

### `campaign/`

Contracts for running campaigns within the Frak ecosystem.

#### `InteractionCampaign.sol`

- Abstract contract providing the base logic for campaigns that distribute rewards based on user interactions with content.
- **Key Features:**
    - Defines an interface for handling user interactions and managing campaign state.
    - Requires implementations to specify:
        - Supported content types.
        - Whether the campaign is currently active.
        - Logic for processing user interactions and distributing rewards.

#### `ReferralCampaign.sol`

- A concrete implementation of `InteractionCampaign` focused on rewarding users for referring new users to the platform.
- **Features:**
    - Integrates with the `ReferralRegistry` to track referral relationships.
    - Supports multi-level referral systems, rewarding both referrers and referees at multiple levels.
    - Allows for customizable reward distribution, where the percentage of rewards allocated to each referral level can be configured.
    - Implements a daily distribution cap to prevent abuse and ensure the sustainability of the campaign.


## Gating

### `gating/`

This directory contains contracts related to content access control and monetization within the Frak ecosystem.

#### `Paywall.sol`

- Allows content creators to restrict access to their content and require payment for access.
- **Key Features:**
    - Enables content creators to define access rules for their content, specifying which users or wallets are allowed to access it.
    - Supports integration with payment tokens, allowing users to pay for content access using designated cryptocurrencies.
    - Can be extended to implement subscription-based access models, where users pay a recurring fee for ongoing content access. 
