# Nexus - Contracts

This repo host the smart contracts related to the Nexus dApp, inside the [Frak](https://frak.id/) ecosystem.

## Addresses

Plugin for Nexus related contracts (only on arbitrum):

| Name                                  | Address                                       |
|--                                     |--                                             |
| Content registry                      | `0xD4BCd67b1C62aB27FC04FBd49f3142413aBFC753`  |
| Community token contract              | `0xf98BA1b2fc7C55A01Efa6C8872Bcee85c6eC54e7`  |
| FRK Paywall token                     | `0x9584A61F70cC4BEF5b8B5f588A1d35740f0C7ae2`  |
| Paywall contract                      | `0x9218521020EF26924B77188f4ddE0d0f7C405f21`  |
| FRK Referral token                    | `0x1Eca7AA9ABF2e53E773B4523B6Dc103002d22e7D`  |
| Nexus Discovery Campaign              | `0x8a37d1B3a17559F2BC4e6613834b1F13d0A623aC`  |

Plugin for the Kernel smart accounts plugins:

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

## Registries

### Content Registry

The content registry is a contract managing every content inside the Frak ecosystem.
Each content is represented by a few on-chain metadata:
 - name
 - domain
 - contentTypes (type of content this content is distributing, like press, video, dapp and stuff)
The domain is immutable for each content, and the id of a content is a `keccak256` hash of it's domain.

Under the hood, it's using an ERC-721 token to represent each content, handle ownership, transfers etc.

### Referral Registry

The referral registry is a contract managing every referral tree inside the Frak ecosystem.
Each tree is identified by a `bytes32` selector.

A referral tree is basicaly the list of user to their referrer. 
Like that you can have some airdrop campaign using a multi level comission system for each users and their referrer.

Each referral tree are public, but need specific permissions to store new user in the referral chain.

For instance, every ContentInteraction contract are granted a write permissions on their own referral tree (referral tree being `keccak256("ContentReferralTree", contentId)`).

## Interactions

Interaction are basically contract receiving some web2 user interaction on a content, and executing some web3 logic around it.

### Content Interaction Manager

This is the higher level contract, responsible to deploy, and store, every ContentInteraction contract.

A Content Interaction contract is specific to a single ContentType, it's responsible to handle the interaction between a user and a specific content (immutable).

The manager will, when requested, deploy the interaction contract for the given content, specificly for it's content types. It will sotre a mapping of all of that, and help end-users retreive the interaction contract for the content they are consuming.

## Modules

All the module used by the Frak ecosystem to help Content or Creator create their custom dApp logic.

### Push Pull Module

This module permit to create a push/pull system, where a user / contract can push some token reward to another user, without directly executing the token transfer.

This can be usefull in system where a user is triggering an action, but we don't want him to pay the gas fee for the token transfer.

- The user can push a reward by calling the `pushReward(address _recipient, uint256 _amount)` method.
- The recipient can pull the reward by calling the `pullReward()` method.
- Another person / contract can pull the reward for a _recipient by calling the `pullReward(address _recipient)` method (ofc, this wall transfer the token to the provided `_recipient` and not to the caller).
- The recipient can also check the reward amount by calling the `getRewardAmount()` method.

### Referral Campaign Module

This module permit to create a referral campaign, where a user can refer another user to get some reward.

- Each campaign is identified by a `bytes32` selector (Same bytes32 as the one for the `referralTree`).
- The campaign is configured during the init (defining nbr of multi tier comission, per level decrease etc). The config contain the following fields:
    - The `maxLevel` permit to define the maximum level of the referral tree we will explore for reward distribution (if set to 0 it will stop to the first referrer).
    - The `perLevelPercentage` permit to define the percentage of reward per level (the first level will get the full comission, the second level will get `reward * perLevelPercentage`, etc).
    - The `token` that will be used for token distribution.
- The implementing contract can then call the `_distributeReferralRewards(bytes32 _tree, address _referee, bool _includeReferee, uint256 _initialReward)` to distribute reward to the referral chain.
    - The `_tree` permit to select the referral tree to use.
    - The `_referee` permit to define the referee to start the reward distribution.
    - The `_initialReward` permit to define the initial reward amount, that will be distributed to the referral chain.
    - The `_includeReferee` permit to include the referee in the reward distribution.
