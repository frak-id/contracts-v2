// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

struct Addresses {
    // Core
    address contentRegistry;
    address referralRegistry;
    address productAdministratorlRegistry;
    // Interactions
    address facetFactory;
    address contentInteractionManager;
    // Campaigns
    address campaignFactory;
    // Token
    address mUSDToken;
}

struct KernelAddresses {
    // WebAuthN
    address p256Wrapper;
    address webAuthNValidator;
    address webAuthNRecoveryAction;
    // InteractionDelegator
    address interactionDelegator;
    address interactionDelegatorValidator;
    address interactionDelegatorAction;
}

struct ContentIds {
    uint256 cNewsPaper;
    uint256 cNewsExample;
    uint256 cEthccDemo;
}

struct DeploymentBlocks {
    uint256 arbSepolia;
}

/// @dev simple contract storing our predetermined address
contract DeterminedAddress {
    // Config
    address internal airdropper = 0x35F3e191523C8701aD315551dCbDcC5708efD7ec;
    address internal contentOwner = 0x7caF754C934710D7C73bc453654552BEcA38223F;

    function _getAddresses() internal pure returns (Addresses memory) {
        return Addresses({
            contentRegistry: 0x758F01B484212b38EAe264F75c0DD7842d510D9c,
            referralRegistry: 0x66820744dBD98b24C05A1fd21809684647c6cC6E,
            productAdministratorlRegistry: 0x35F3e191523C8701aD315551dCbDcC5708efD7ec,
            contentInteractionManager: 0xB3fc8bD4e71a15a674ed6BAb63e884720FC4A3B4,
            facetFactory: 0xce9e06e2139Fc13079C778a172769c3333f33fC1,
            campaignFactory: 0xB178c17AC5ad0455b1a10b05d25Fe4847567Ef1D,
            mUSDToken: 0x56039fa1a804F614eBD714139F29a3ff4DB57ad6
        });
    }

    function _getKernelAddresses() internal pure returns (KernelAddresses memory) {
        return KernelAddresses({
            p256Wrapper: 0x97A24c95E317c44c0694200dd0415dD6F556663D,
            webAuthNValidator: 0xF05f18D9312f10d1d417c45040B8497899f66A5E,
            webAuthNRecoveryAction: 0x8b29229515D3e5b829D59617A791b5B3a2c32ff1,
            interactionDelegator: 0x4b8350E6291063bF14ca1E4379147a3bd23714CB,
            interactionDelegatorValidator: 0xb33cc9Aea3f6e1125179Ec0A1D9783eD3717d04C,
            interactionDelegatorAction: 0xF9aC3355363a1F3b501Df411cA4d08e8F854bF76
        });
    }

    function _getContentIds() internal pure returns (ContentIds memory) {
        return ContentIds({
            cNewsPaper: 20376791661718660580662410765070640284736320707848823176694931891585259913409,
            cNewsExample: 8073960722007594212918575991467917289452723924551607525414094759273404023523,
            cEthccDemo: 33953649417576654953995537313820306697747390492794311279756157547821320957282
        });
    }

    function _getContentIdsArr() internal pure returns (uint256[] memory arr) {
        ContentIds memory contentIds = _getContentIds();
        arr = new uint256[](3);
        arr[0] = contentIds.cNewsPaper;
        arr[1] = contentIds.cNewsExample;
        arr[2] = contentIds.cEthccDemo;
    }

    function _getDeploymentBlocks() internal pure returns (DeploymentBlocks memory) {
        return DeploymentBlocks({arbSepolia: 66229858});
    }
}
