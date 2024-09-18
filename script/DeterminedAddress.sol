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
    uint256 pNewsPaper;
    uint256 pEthccDemo;
}

struct DeploymentBlocks {
    uint256 arbSepolia;
}

/// @dev simple contract storing our predetermined address
contract DeterminedAddress {
    // Config
    address internal airdropper = 0x35F3e191523C8701aD315551dCbDcC5708efD7ec;
    address internal productOwner = 0x7caF754C934710D7C73bc453654552BEcA38223F;

    // news paper product
    uint256 internal pNewsPaper = 20376791661718660580662410765070640284736320707848823176694931891585259913409;
    uint256 internal pEthccWallet = 33953649417576654953995537313820306697747390492794311279756157547821320957282;

    function _getAddresses() internal pure returns (Addresses memory) {
        return Addresses({
            productRegistry: 0x33B856a553332998fbA771ce6D568eb818d537D3,
            referralRegistry: 0xFFcde7Fbd0d868bf06B520020617fb74D927C639,
            productAdministratorlRegistry: 0xE4B8348CAC195C37ee55DfD2faD232a3353E3d26,
            productInteractionManager: 0x6c424867c89fE6e13b05468C4B5244E78b74bDff,
            facetFactory: 0xd848068035cf62757cC458D349A9Fe549F5f6B60,
            campaignFactory: 0xC94ae540F147B83C4D55A6a5870F468f8ee79367,
            mUSDToken: 0x43838DCb58a61325eC5F31FD70aB8cd3540733d1
        });
    }

    function _getKernelAddresses() internal pure returns (KernelAddresses memory) {
        return KernelAddresses({
            p256Wrapper: 0x97A24c95E317c44c0694200dd0415dD6F556663D,
            webAuthNValidator: 0xF05f18D9312f10d1d417c45040B8497899f66A5E,
            webAuthNRecoveryAction: 0x8b29229515D3e5b829D59617A791b5B3a2c32ff1,
            interactionDelegator: 0xF6728220A504c4e80Ffe6B7c9bc44B21f2D6FBaf,
            interactionDelegatorValidator: 0x0A15995CA6C7a7a67a41e0EBff105326bbD55716,
            interactionDelegatorAction: 0xaA554125622489B64734901dA15A2a5637398e5E
        });
    }

    function _getProductIds() internal view returns (ProductIds memory) {
        return ProductIds({pNewsPaper: pNewsPaper, pEthccDemo: pEthccWallet});
    }

    function _getProductIdsArr() internal view returns (uint256[] memory arr) {
        arr = new uint256[](2);
        arr[0] = pNewsPaper;
        arr[1] = pEthccWallet;
    }

    function _getDeploymentBlocks() internal pure returns (DeploymentBlocks memory) {
        return DeploymentBlocks({arbSepolia: 66229858});
    }
}
