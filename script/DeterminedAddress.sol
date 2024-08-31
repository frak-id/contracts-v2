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
            productRegistry: 0xdA7fBD02eb048bDf6f1607122eEe071e44f0b9F2,
            referralRegistry: 0xcf5855d9825578199969919F1696b80388111403,
            productAdministratorlRegistry: 0x62254d732C078BF0484EA7dBd61f7F620184F95e,
            productInteractionManager: 0x5c449C1777Fa729C4136DDF81585FDd7512Ae8bb,
            facetFactory: 0x66B1a8614464C840e552F6804E79a1AB0888cB48,
            campaignFactory: 0xBE461b8Eb39050cd1c41aaa2f686C93Ec4a5958E,
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
            interactionDelegatorAction: 0xD46171ae153dc69b1A2A1a8dF75Ea92e99234afA
        });
    }

    function _getProductIds() internal view returns (ProductIds memory) {
        return ProductIds({pNewsPaper: pNewsPaper, pEthccDemo: pEthccWallet});
    }

    function _getProductIdsArr() internal view returns (uint256[] memory arr) {
        arr = new uint256[](2);
        arr[0] = pNewsPaper;
        arr[2] = pEthccWallet;
    }

    function _getDeploymentBlocks() internal pure returns (DeploymentBlocks memory) {
        return DeploymentBlocks({arbSepolia: 66229858});
    }
}
