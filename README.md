# Frak - Contracts v2

This repository hosts the smart contracts related to the Nexus dApp, within the [Frak](https://frak.id/) ecosystem. 

This project contains a suite of smart contracts that manage product registrations, user interactions, referral systems, and reward campaigns.

## Addresses

### Frak ecosystem

Addresses of the Frak contracts, deployed on Arbitrum and Arbitrum Sepolia.

| Name                           | Address                                       |
|--------------------------------|-----------------------------------------------|
| Product Registry               | `0xdA7fBD02eb048bDf6f1607122eEe071e44f0b9F2`  |
| Referral Registry              | `0xcf5855d9825578199969919F1696b80388111403`  |
| Product Administrator Registry | `0x62254d732C078BF0484EA7dBd61f7F620184F95e`  |
| Product Interaction Manager    | `0x5c449C1777Fa729C4136DDF81585FDd7512Ae8bb`  |
| Facet Factory                  | `0x2f22e1EF391E744be68bB5Ac4D2f3024F2d6A9b8`  |
| Campaign Factory               | `0xBE461b8Eb39050cd1c41aaa2f686C93Ec4a5958E`  |
| mUSD Token                     | `0x56039fa1a804F614eBD714139F29a3ff4DB57ad6`  |

### Kernel plugins

Plugins for the Kernel smart accounts. They can be deployed on any chain via the `deploy/` folder, using [orchestra](https://github.com/zerodevapp/orchestra).

| Name                                  | Address                                       |
|---------------------------------------|-----------------------------------------------|
| Generic                                                                               |
| P256 Signature checker Wrapper        | `0x97A24c95E317c44c0694200dd0415dD6F556663D`  |
| MultiWebAuthN - Kernel v2             | `0xF05f18D9312f10d1d417c45040B8497899f66A5E`  |
| MultiWebAuthN Recovery - Kernel v2    | `0x8b29229515D3e5b829D59617A791b5B3a2c32ff1`  |
| Interaction delegator                 | `0x4b8350E6291063bF14ca1E4379147a3bd23714CB`  |
| Interaction delegator validator       | `0xb33cc9Aea3f6e1125179Ec0A1D9783eD3717d04C`  |
| Interaction delegator action          | `0xD46171ae153dc69b1A2A1a8dF75Ea92e99234afA`  |


## Folder Structure

```
src
├── campaign
│   ├── CampaignFactory.sol
│   ├── InteractionCampaign.sol
│   └── ReferralCampaign.sol
├── constants
├── interaction
│   ├── InteractionFacetsFactory.sol
│   ├── ProductInteractionDiamond.sol
│   ├── ProductInteractionManager.sol
│   ├── facets
│   │   ├── DappInteractionFacet.sol
│   │   ├── IInteractionFacet.sol
│   │   ├── PressInteractionFacet.sol
│   │   └── ReferralFeatureFacet.sol
│   └── lib
├── interfaces
├── kernel
│   ├── interaction
│   ├── types
│   ├── utils
│   └── webauthn
├── modules
├── registry
│   ├── ProductAdministratorRegistry.sol
│   ├── ProductRegistry.sol
│   └── ReferralRegistry.sol
├── stylus
└── tokens
```
## Registries

The `registry/` directory houses contracts that function as essential data registries within the Frak ecosystem. These registries manage crucial information about products, referrals, and administrative roles.

### ProductRegistry.sol

The ProductRegistry manages metadata associated with products within the Frak ecosystem.

Key features:
- Represents each product as a unique ERC-721 token.
- Identifies products by a unique domain.
- Stores product metadata: name, domain, and supported product types.
- Handles product registration, metadata updates, ownership transfers, and product discovery.

### ReferralRegistry.sol

The ReferralRegistry manages referral trees for implementing referral programs and reward distributions.

Key features:
- Supports creation of multiple referral trees, each identified by a unique `bytes32` selector.
- Tracks referrals within each tree, establishing relationships between referrers and referees.
- Controls write access to referral trees to ensure only authorized contracts or users can add new referrals.

### ProductAdministratorRegistry.sol

The ProductAdministratorRegistry manages roles and permissions for products within the Frak ecosystem.

Key features:
- Greatly inspired by solady's OwnableRoles contract, but uses productId as a key.
- Interacts with ProductRegistry to verify product ownership.
- Only the owner of a product can update permissions for users.
- Provides role-based access control for product-related operations.

Integration:
These registries work together to provide a comprehensive management system for the Frak ecosystem:
- The ProductRegistry serves as the source of truth for product information.
- The ReferralRegistry enables the implementation of complex referral programs.
- The ProductAdministratorRegistry ensures that only authorized users can perform specific actions on products.

Other components of the system, such as the interaction diamonds and campaign contracts, frequently interact with these registries to retrieve information, verify permissions, and update states as necessary.

## Interactions

The `interaction/` directory manages user interactions with products using a custom adaptation of the diamond pattern.

### ProductInteractionDiamond.sol

- Implements a custom version of the diamond pattern, acting as the main contract for product interactions.
- Uses delegatecall to interact with specific facets based on product type or feature.
- Maintains root storage for shared data across facets.

Key features:
- Each ProductInteractionDiamond is associated with a single product.
- Facets are not bound to specific method signatures, allowing for more flexible interaction handling.
- Does not implement looping through facets; instead, it directly delegates to the appropriate facet based on the product type or feature.

### InteractionFacetsFactory.sol

- Responsible for creating and deploying new interaction facets.

### ProductInteractionManager.sol

- Central orchestrator for deploying and managing ProductInteractionDiamond contracts.
- Coordinates with the ProductRegistry to determine the appropriate interaction facets based on product metadata.

### Facets

The `facets/` subdirectory contains specific interaction logic for different product types or features:

- `DappInteractionFacet.sol`: Handles interactions specific to dapp products.
- `PressInteractionFacet.sol`: Manages interactions related to press products.
- `ReferralFeatureFacet.sol`: Implements referral-related interactions.
- `IInteractionFacet.sol`: Likely an interface defining common interaction methods.

Each facet implements logic for a specific type of product or a particular feature, and can be called via delegatecall from the main ProductInteractionDiamond contract.

Integration:
- The interaction system interacts with the registries (ProductRegistry, ReferralRegistry, ProductAdministratorRegistry) to retrieve product information, manage referrals, and check permissions.
- It may also interact with campaign contracts to trigger rewards based on user interactions.

Note: The exact details of how facets are selected and called, and how storage is shared between the main diamond contract and its facets, may vary based on the specific implementation of this custom diamond pattern adaptation.

## Campaigns

The `campaign/` directory contains contracts related to campaign management and execution within the Frak ecosystem. These contracts work in conjunction with the interaction system to reward users based on their activities.

### CampaignFactory.sol

- Responsible for creating and deploying new campaign contracts.
- Likely manages the lifecycle of campaigns, including creation, activation, and potentially deactivation.

Key features:
- May interact with the ProductAdministratorRegistry to ensure only authorized users can create or manage campaigns for specific products.

### InteractionCampaign.sol

- An abstract contract providing the base logic for campaigns that distribute rewards based on user interactions with products.

Key features:
- Likely defines an interface for handling user interactions and managing campaign state.
- May include common functionality shared across different types of campaigns.

### ReferralCampaign.sol

- A concrete implementation of InteractionCampaign, focused on rewarding users for referring new users to the platform.

Key features:
- Likely integrates with the ReferralRegistry to track referral relationships.
- May implement specific reward distribution logic for referral activities.

Integration:
- These campaign contracts interact with the ProductInteractionDiamond and various registries to:
  - Receive information about user interactions.
  - Verify product and user information.
  - Check permissions for campaign-related actions.
  - Update campaign states and distribute rewards.

Note: The exact mechanisms for reward calculation, distribution, and the specific types of campaigns supported may vary based on the implementation details of these contracts.