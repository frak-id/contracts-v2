// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

struct Addresses {
    // Core
    address contentRegistry;
    address referralRegistry;
    address facetFactory;
    address contentInteractionManager;
    // Gating
    address paywallToken;
    address paywall;
    // Community
    address communityToken;
}

struct ContentIds {
    uint256 cLeMonde;
    uint256 cLequipe;
    uint256 cWired;
    uint256 cFrak;
}

/// @dev simple contract storing our predetermined address
contract DeterminedAddress {
    // Config
    address internal airdropper = 0x35F3e191523C8701aD315551dCbDcC5708efD7ec;

    /*
    Deployments blocks (could be usefull for fork testing):
    - arb sepolia: 52222107
     */

    function _getAddresses() internal pure returns (Addresses memory) {
        return Addresses({
            contentRegistry: 0xc02209e937dB50C80AA1A280f9172163D8aC6a38,
            referralRegistry: 0x0a1d4292bC42d39e02b98A6AF9d2E49F16DBED43,
            contentInteractionManager: 0x71a54b7Edb803b0FB6c7A930794BcA13587Af21b,
            facetFactory: 0xfb170A73383Ec2E15097d80b736FeDF21a8F1E01,
            paywallToken: 0x9584A61F70cC4BEF5b8B5f588A1d35740f0C7ae2,
            paywall: 0x99F44C46fb00b94f5Cff57cbbF3d57303469E884,
            communityToken: 0x932145A69BaF498D7F87D06db2E6c7963BF86E85
        });
    }

    function _getContentIds() internal pure returns (ContentIds memory) {
        return ContentIds({
            cLeMonde: 106219508196454080375526586478153583586194937194493887259467424694676997453395,
            cLequipe: 108586150798115180574743190405367285583167702751783717273705027881651322809951,
            cWired: 61412812549033025435811962204424170589965658763482764336017940556663446417829,
            cFrak: 20376791661718660580662410765070640284736320707848823176694931891585259913409
        });
    }
}
