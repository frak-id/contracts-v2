# Frak - Contracts v2

This repo hosts the smart contracts related to the Nexus dApp, inside the [Frak](https://frak.id/) ecosystem.

## TODO:
 - Lifebuoy from solady a bit everywhere
 - P256 from vectorised for passkey verification? https://github.com/Vectorized/solady/blob/main/src/utils/P256.sol
 - Content -> Product

## Addresses

### Frak ecosystem

Address of the Frak contracts, deployed on Arbitrum and arbitrum sepolia.


| Name                      | Address                                       |
|---------------------------|-----------------------------------------------|
| Content Registry          | `0x758F01B484212b38EAe264F75c0DD7842d510D9c`  |
| Referral Registry         | `0x66820744dBD98b24C05A1fd21809684647c6cC6E`  |
| Content Interaction Mgr   | `0xB3fc8bD4e71a15a674ed6BAb63e884720FC4A3B4`  |
| Content Facet Factory     | `0xce9e06e2139Fc13079C778a172769c3333f33fC1`  |
| Content Campaign Factory  | `0xB178c17AC5ad0455b1a10b05d25Fe4847567Ef1D`  |

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
| MultiWebAuthN - Kernel v2             | `0xF05f18D9312f10d1d417c45040B8497899f66A5E`  |
| MultiWebAuthN Recovery - Kernel v2    | `0x8b29229515D3e5b829D59617A791b5B3a2c32ff1`  |
| Interaction delegator                 | `0x4b8350E6291063bF14ca1E4379147a3bd23714CB`  |
| Interaction delegator validator       | `0xb33cc9Aea3f6e1125179Ec0A1D9783eD3717d04C`  |
| Interaction delegator action          | `0xF9aC3355363a1F3b501Df411cA4d08e8F854bF76`  |


## Folder Structure

```
├─src
├── campaign
│   ├── InteractionCampaign.sol
│   └── ReferralCampaign.sol
├── interaction
│   ├── lib/
│   ├── facets
│   │ ├── IInteractionFacet.sol
│   │ ├── DappInteractionFacet.sol
│   │ └── PressInteractionFacet.sol
│   ├── InteractionFacetsFactory.sol
│   ├── ContentInteractionDiamond.sol
│   └── ContentInteractionManager.sol
├── registry
│   ├── ContentRegistry.sol
│   └── ReferralRegistry.sol
├── constants
├── tokens
├── kernel
```

## Registries

### `registry/`

This directory houses contracts that function as registries for essential data within the Frak ecosystem. 

#### `ContentRegistry.sol`

- Manages metadata associated with content within the Frak ecosystem.
- Each content piece is represented by a unique ERC-721 token and is identified by a unique domain.
- Stores content metadata: name, domain, and supported content types.
- Handles content registration, metadata updates, ownership transfers, and content discovery.

#### `ReferralRegistry.sol`

- Manages referral trees for implementing referral programs and reward distributions.
- Allows creation of referral trees, each identified by a unique `bytes32` selector.
- Tracks referrals within each tree, establishing relationships between referrers and referees.
- Controls write access to referral trees to ensure only authorized contracts or users can add new referrals.

## Interactions

### `interaction/`

This directory manages user interactions with content and leverages a diamond pattern for extensibility.

#### `ContentInteractionManager.sol`

- Central orchestrator for deploying, managing, and upgrading interaction logic within the Frak ecosystem.
- **Responsibilities:**
    - Deploys and manages `ContentInteractionDiamond` contracts, one per piece of content.
    - Associates `InteractionCampaign` contracts with content interactions.
    - Coordinates with the `ContentRegistry` to determine the appropriate interaction facets based on content metadata.
    - Authorizes interaction diamonds to manage referral relationships in the `ReferralRegistry`.
    - Upgrades facet logic for interaction diamonds, providing flexibility and future-proofing the system. 

#### `ContentInteractionDiamond.sol`

- Implements the core logic of the diamond pattern, acting as a proxy that delegates function calls to specific facets.
- **Key Features:**
    - Each `ContentInteractionDiamond` is associated with a single piece of content.
    - It handles common tasks like:
        - Validating user interactions using EIP-712 signatures for security.
        - Managing interactions with the `ReferralRegistry` for referral tracking.
        - Forwarding interaction data to attached `InteractionCampaign` contracts.
    - It delegates the actual handling of content-specific interactions (e.g., opening an article, liking a video) to dedicated facet contracts.
    - This diamond pattern allows for adding new content types and interaction logic without modifying the core `ContentInteractionDiamond` contract. 

### `interaction/facets/` 

This directory contains the facet contracts that implement specific interaction logic for different content types.

#### `PressInteractionFacet.sol`

- A facet contract specifically designed to handle user interactions with press content (e.g., articles).
- **Functionality:**
    - Tracks user interactions like article opens (distinguishing direct opens and opens via shared links), article reads, share link creation, and share link usage.
    - Emits detailed events for each interaction to provide an audit trail for off-chain systems.
    - Can be extended to integrate with reward mechanisms and other campaign logic.

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
