# Frak - Contracts v2

This repository hosts the smart contracts related to the Nexus dApp, within the [Frak](https://frak.id/) ecosystem. 

This project contains a suite of smart contracts that manage product registrations, user interactions, referral systems, and reward campaigns.

## Addresses

### Frak ecosystem

Addresses of the Frak contracts, deployed on Arbitrum and Arbitrum Sepolia.

| Name                           | Address                                       |
|--------------------------------|-----------------------------------------------|
| Product Registry               | `0x9100000000290000D9a49572110030ba00E0F40b`  |
| Referral Registry              | `0x5439e7b27500f7000A6DCD00006D000082510000`  |
| Product Administrator Registry | `0x0000000000000823EaD12075a50A2a6520966e5c`  |
| Purchase Oracle                | `0x0000EC17000000e783CA00Ee06890000114C100d`  |
| Product Interaction Manager    | `0x0000000000009720dc2B0D893f7Ec2a878d21AeC`  |
| Facet Factory                  | `0x0000003b064eCB7cdB7ff052c4Ee80Dff10000Cd`  |
| Campaign Factory               | `0x0000000000278e0EFbC5968020A798AaB1571E5c`  |
| Campaign Bank Factory          | `0x00000000003604CF2d09f4Aa3B878843A765015d`  |

### Kernel plugins

Plugins for the Kernel smart accounts.

| Name                                  | Address                                       |
|---------------------------------------|-----------------------------------------------|
| Generic                                                                               |
| P256 Signature checker Wrapper        | `0x00e4005A00007384000000B0a8A0F300DD9fCAFA`  |
| MultiWebAuthN - Kernel v2             | `0x0000000000Fb9604350a25E826B050D859FE7b77`  |
| MultiWebAuthN Recovery - Kernel v2    | `0x000000000093c960bC9F9Dc93509E394a96c7FD9`  |
| Interaction delegator                 | `0x0000000000915Bae6248227914666Afd11Ad706e`  |
| Interaction delegator validator       | `0x00000000002f84e026BbA7983F3c189D0C6dc8Fa`  |
| Interaction delegator action          | `0x00000000001BF7FE0EEBf7c66E1e624D52a12FAD`  |


## Folder Structure

```
src
├── campaign
│   ├── CampaignBank.sol
│   ├── CampaignBankFactory.sol
│   ├── InteractionCampaign.sol
│   └── ReferralCampaign.sol
│   ├── CampaignFactory.sol
├── constants
├── interaction
│   ├── InteractionFacetsFactory.sol
│   ├── ProductInteractionDiamond.sol
│   ├── ProductInteractionManager.sol
│   ├── facets
│   │   ├── DappInteractionFacet.sol
│   │   ├── IInteractionFacet.sol
│   │   ├── PressInteractionFacet.sol
│   │   ├── PurchaseInteractionFacet.sol
│   │   ├── WebShopInteractionFacet.sol
│   │   └── ReferralFeatureFacet.sol
│   └── lib
├── interfaces
├── kernel
│   ├── interaction
│   ├── types
│   ├── utils
│   └── webauthn
├── modules
├── oracle
│   └── PurchaseOracle.sol
├── registry
│   ├── ProductAdministratorRegistry.sol
│   ├── ProductRegistry.sol
│   └── ReferralRegistry.sol
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