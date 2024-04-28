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

Plugin for the Kernel smart accounts plugins:

| Name                                  | Address                                       |
|--                                     |--                                             |
| Generic                                                                               |
| P256 Signature checker Wrapper        | `0x97A24c95E317c44c0694200dd0415dD6F556663D`  |
| Kernel V3                                                                             |
| SingleWebAuthN - Kernel v3            | `0x2563cEd40Af6f51A3dF0F1b58EF4Cf1B994fDe12`  |
| MultiWebAuthN - Kernel v3             | `0x93228CA325349FC7d8C397bECc0515e370aa4555`  |
| Kernel V2                                                                             |
| MultiWebAuthN - Kernel v2             | `0xD546c4Ba2e8e5e5c961C36e6Db0460Be03425808`  |
| MultiWebAuthN Recovery - Kernel v2    | `0x67236B8AAF4B32d2D3269e088B1d43aef7736ab9`  |

## Modules

All the module used by the Frak ecosystem to help Content or Creator create their custom dApp logic.

### Referral Module

This module permit to create simple referral system, with multi tree (tree identified by a `bytes32` selector).

- The referral chain are stored from `referee` => `referrer`. It's easing the process to get the referrer of a user, most commonly action.
- A user can add his referrer chain by using either of this two methods:
    - Call the `saveReferrer(bytes32 _selector, address _referrer)` method.
    - Create and sign the typed data `SaveReferrer`, then anyone could sent the signature to add it to the referral chain.
- Two main interaction possible with it:
    - The hook `onUserReferred(bytes32 _selector, address _referrer, address _referee)` will be called when a user is referred by another one.
    - The function `getReferrer(bytes32 _selector, address _referee) returns (address)` will return the referrer of a user. 
