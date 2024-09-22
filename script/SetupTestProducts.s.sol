// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, DeterminedAddress} from "./DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";

import {CampaignBank} from "src/campaign/CampaignBank.sol";
import {CampaignBankFactory} from "src/campaign/CampaignBankFactory.sol";
import {
    PRODUCT_TYPE_DAPP,
    PRODUCT_TYPE_FEATURE_REFERRAL,
    PRODUCT_TYPE_PRESS,
    ProductTypes
} from "src/constants/ProductTypes.sol";
import {INTERCATION_VALIDATOR_ROLE} from "src/constants/Roles.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";
import {ProductInteractionManager} from "src/interaction/ProductInteractionManager.sol";
import {ProductRegistry} from "src/registry/ProductRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";
import {mUSDToken} from "src/tokens/mUSDToken.sol";

contract SetupTestProducts is Script, DeterminedAddress {
    address internal interactionValidator = 0x8747C17970464fFF597bd5a580A72fCDA224B0A1;

    function run() public {
        Addresses memory addresses = _getAddresses();
        ProductInteractionManager productInteractionManager =
            ProductInteractionManager(addresses.productInteractionManager);

        // Mint the products
        // uint256[] memory productIds = _mintProducts(ProductRegistry(addresses.productRegistry));
        uint256[] memory productIds = _getProductIdsArr();

        // Setup the interactions
        // _setupInteractions(productInteractionManager, productIds);

        // Setup the campaign banks
        _setupBanks(addresses, productIds);
    }

    /// @dev Mint the test products
    function _mintProducts(ProductRegistry productRegistry) internal returns (uint256[] memory productIds) {
        productIds = new uint256[](2);
        vm.startBroadcast();

        // Mint the tests products
        uint256 pEthccDemo = _mintProduct(
            productRegistry,
            PRODUCT_TYPE_PRESS | PRODUCT_TYPE_DAPP | PRODUCT_TYPE_FEATURE_REFERRAL,
            "Frak - EthCC demo",
            "ethcc.news-paper.xyz"
        );
        uint256 pNewsPaper = _mintProduct(
            productRegistry, PRODUCT_TYPE_PRESS | PRODUCT_TYPE_FEATURE_REFERRAL, "A Positive World", "news-paper.xyz"
        );
        vm.stopBroadcast();

        console.log("Product id:");
        console.log(" - News-Paper: %s", pNewsPaper); // 20376791661718660580662410765070640284736320707848823176694931891585259913409
        console.log(" - EthCC demo: %s", pEthccDemo); // 33953649417576654953995537313820306697747390492794311279756157547821320957282

        productIds[0] = pEthccDemo;
        productIds[1] = pNewsPaper;
    }

    /// @dev Mint a product with the given name and domain
    function _mintProduct(
        ProductRegistry _productRegistry,
        ProductTypes _productTypes,
        string memory _name,
        string memory _domain
    ) internal returns (uint256) {
        return _productRegistry.mint(_productTypes, _name, _domain, productOwner);
    }

    /// @dev Setup the interaction contracts for the given products
    function _setupInteractions(ProductInteractionManager _interactionManager, uint256[] memory _productIds) internal {
        console.log("Setting up interactions");
        vm.startBroadcast();
        for (uint256 i = 0; i < _productIds.length; i++) {
            // Deploy the interaction contract
            _interactionManager.deployInteractionContract(_productIds[i]);
        }
        vm.stopBroadcast();
    }

    /// @dev Setup the interaction contracts for the given products
    function _setupBanks(Addresses memory addresses, uint256[] memory _productIds) internal {
        console.log("Setting up banks");
        CampaignBankFactory campaignBankFactory = CampaignBankFactory(addresses.campaignBankFactory);
        vm.startBroadcast();
        for (uint256 i = 0; i < _productIds.length; i++) {
            // Deploy the interaction contract
            CampaignBank bank = campaignBankFactory.deployCampaignBank(_productIds[i], addresses.mUSDToken);
            // Mint a few tokens to the bank
            mUSDToken(addresses.mUSDToken).mint(address(bank), 10_000 ether);
            // Enable the bank to distribute tokens
            bank.updateDistributionState(true);
        }
        vm.stopBroadcast();
    }
}
