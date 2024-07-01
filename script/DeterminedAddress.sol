// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

struct Addresses {
    // Core
    address contentRegistry;
    address referralRegistry;
    address facetFactory;
    address campaignFactory;
    address contentInteractionManager;
    // Gating
    address paywall;
    // Community
    address communityToken;
    // Token
    address mUSDToken;
    address paywallToken;
}

struct ContentIds {
    uint256 cLeMonde;
    uint256 cLequipe;
    uint256 cWired;
    uint256 cFrak;
    uint256 cFrakDapp;
}

struct DeploymentBlocks {
    uint256 arbSepolia;
}

/// @dev simple contract storing our predetermined address
contract DeterminedAddress {
    // Config
    address internal airdropper = 0x35F3e191523C8701aD315551dCbDcC5708efD7ec;

    function _getAddresses() internal pure returns (Addresses memory) {
        return Addresses({
            contentRegistry: 0xC110ecb55EbAa4Ea9eFC361C4bBB224A6664Ea45,
            referralRegistry: 0x0a1d4292bC42d39e02b98A6AF9d2E49F16DBED43,
            contentInteractionManager: 0xC97D72A8a9d1D2Ed326EB04f2d706A21cEe2B94E,
            facetFactory: 0x27EFC7876a0C21239fA33eb62Ae55591D5204781,
            campaignFactory: 0x440B19d7694f4B8949b02e674870880c5e40250C,
            paywall: 0x1d11207BD915D1f8A4393D20AB318a1a961CCE6F,
            communityToken: 0x5E7759F47b5992DFB85Ef38dD48A9201aDF24b75,
            paywallToken: 0x9584A61F70cC4BEF5b8B5f588A1d35740f0C7ae2,
            mUSDToken: 0x56039fa1a804F614eBD714139F29a3ff4DB57ad6
        });
    }

    function _getContentIds() internal pure returns (ContentIds memory) {
        return ContentIds({
            cLeMonde: 106219508196454080375526586478153583586194937194493887259467424694676997453395,
            cLequipe: 108586150798115180574743190405367285583167702751783717273705027881651322809951,
            cWired: 61412812549033025435811962204424170589965658763482764336017940556663446417829,
            cFrak: 20376791661718660580662410765070640284736320707848823176694931891585259913409,
            cFrakDapp: 79779516358427208576129661848423776934526633566649852115422670859041784133448
        });
    }

    function _getContentIdsArr() internal pure returns (uint256[] memory arr) {
        ContentIds memory contentIds = _getContentIds();
        arr = new uint256[](4);
        arr[0] = contentIds.cLeMonde;
        arr[1] = contentIds.cLequipe;
        arr[2] = contentIds.cWired;
        arr[3] = contentIds.cFrak;
    }

    function _getDeploymentBlocks() internal pure returns (DeploymentBlocks memory) {
        return DeploymentBlocks({arbSepolia: 54321880});
    }
}
