// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

struct Addresses {
    // Core
    address productRegistry;
    address referralRegistry;
    address productAdministratorlRegistry;
    // Interactions
    address facetFactory;
    address productInteractionManager;
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

struct ProductIds {
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
    address internal productOwner = 0x7caF754C934710D7C73bc453654552BEcA38223F;

    function _getAddresses() internal pure returns (Addresses memory) {
        return Addresses({
            productRegistry: 0x498796b3b26c9B1519d1E0b6E4927CEb85A05b75,
            referralRegistry: 0xcf5855d9825578199969919F1696b80388111403,
            productAdministratorlRegistry: 0x9eE2fB93cc0C74b540A34981EFE6e26231e75Bc7,
            productInteractionManager: 0x499E46DAB24BAF9b1Ab330fc9B4E3275b902990a,
            facetFactory: 0x5c53407569aaF663b5E22E84956459B2Bd97eE1A,
            campaignFactory: 0x0E2d197B9079A5128D4d2728EFFFf234934162B1,
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
            interactionDelegatorAction: 0x0e88C66979Fd2EA55D0E09012196D4f2BcB71a76
        });
    }

    function _getProductIds() internal pure returns (ProductIds memory) {
        return ProductIds({
            cNewsPaper: 20376791661718660580662410765070640284736320707848823176694931891585259913409,
            cNewsExample: 8073960722007594212918575991467917289452723924551607525414094759273404023523,
            cEthccDemo: 33953649417576654953995537313820306697747390492794311279756157547821320957282
        });
    }

    function _getProductIdsArr() internal pure returns (uint256[] memory arr) {
        ProductIds memory productIds = _getProductIds();
        arr = new uint256[](3);
        arr[0] = productIds.cNewsPaper;
        arr[1] = productIds.cNewsExample;
        arr[2] = productIds.cEthccDemo;
    }

    function _getDeploymentBlocks() internal pure returns (DeploymentBlocks memory) {
        return DeploymentBlocks({arbSepolia: 66229858});
    }
}
