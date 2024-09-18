// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, DeterminedAddress} from "./DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
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
        _setupInteractions(productInteractionManager, productIds);

        _setupCampaigns(productInteractionManager, addresses, productIds);
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

    bytes4 private constant REFERRAL_CAMPAIGN_IDENTIFIER = bytes4(keccak256("frak.campaign.referral"));

    /// @dev Setup the itneraction campaigns for the given products
    function _setupCampaigns(
        ProductInteractionManager _interactionManager,
        Addresses memory addresses,
        uint256[] memory _productIds
    ) internal {
        console.log("Setting up campaigns");
        for (uint256 i = 0; i < _productIds.length; i++) {
            uint256 productId = _productIds[i];

            vm.startBroadcast();

            address campaign = _interactionManager.deployCampaign(
                productId, REFERRAL_CAMPAIGN_IDENTIFIER, _campaignDeploymentData(addresses)
            );

            // Add a few mUSD to the deployed campaign
            mUSDToken(addresses.mUSDToken).mint(address(campaign), 100_000 ether);

            vm.stopBroadcast();
        }
    }

    function _campaignDeploymentData(Addresses memory addresses) private pure returns (bytes memory) {
        ReferralCampaign.CampaignConfig memory config = ReferralCampaign.CampaignConfig({
            token: addresses.mUSDToken,
            initialReward: 10 ether,
            userRewardPercent: 5_000, // 50%
            distributionCapPeriod: 1 days,
            distributionCap: 500 ether,
            startDate: uint48(0),
            endDate: uint48(0),
            name: ""
        });

        return abi.encode(config);
    }
}
