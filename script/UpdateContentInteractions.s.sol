// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, DeterminedAddress, ProductIds} from "./DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
import {
    PRODUCT_TYPE_DAPP,
    PRODUCT_TYPE_FEATURE_REFERRAL,
    PRODUCT_TYPE_PRESS,
    ProductTypes
} from "src/constants/ProductTypes.sol";
import {InteractionFacetsFactory} from "src/interaction/InteractionFacetsFactory.sol";
import {ProductInteractionManager} from "src/interaction/ProductInteractionManager.sol";
import {ICampaignFactory} from "src/interfaces/ICampaignFactory.sol";
import {ProductAdministratorRegistry} from "src/registry/ProductAdministratorRegistry.sol";
import {ProductRegistry} from "src/registry/ProductRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";

/// todo: Should be refacto to update the faucet factory, set it on the productInteractionManager, and then call the update function
contract UpdateProductInteractions is Script, DeterminedAddress {
    function run() public {
        // _updateManager();
        // _updateProducts();
        _updateInteractions();
        // _updateCampaigns();
    }

    function _updateManager() internal {
        Addresses memory addresses = _getAddresses();

        ProductInteractionManager currentManager = ProductInteractionManager(addresses.productInteractionManager);

        vm.startBroadcast();

        address newImplem = address(
            new ProductInteractionManager{salt: 0}(
                ProductRegistry(addresses.productRegistry),
                ReferralRegistry(addresses.referralRegistry),
                ProductAdministratorRegistry(addresses.productAdministratorlRegistry)
            )
        );
        currentManager.upgradeToAndCall(newImplem, "");

        vm.stopBroadcast();
    }

    function _updateInteractions() internal {
        ProductIds memory productIds = _getProductIds();
        Addresses memory addresses = _getAddresses();

        ProductInteractionManager productInteractionManager =
            ProductInteractionManager(addresses.productInteractionManager);

        vm.startBroadcast();

        // update the facet factory
        productInteractionManager.updateFacetsFactory(InteractionFacetsFactory(addresses.facetFactory));

        // Update the interaction contracts
        productInteractionManager.updateInteractionContract(productIds.pNewsPaper);
        productInteractionManager.updateInteractionContract(productIds.pEthccDemo);

        vm.stopBroadcast();
    }

    function _updateCampaigns() internal {
        Addresses memory addresses = _getAddresses();

        ProductInteractionManager productInteractionManager =
            ProductInteractionManager(addresses.productInteractionManager);

        vm.startBroadcast();

        // update the campaign factory
        productInteractionManager.updateCampaignFactory(ICampaignFactory(addresses.campaignFactory));

        vm.stopBroadcast();
    }

    function _updateProducts() internal {
        Addresses memory addresses = _getAddresses();

        ProductRegistry productRegistry = ProductRegistry(addresses.productRegistry);

        vm.startBroadcast();

        // Update each products
        productRegistry.updateMetadata(
            _getProductIds().pNewsPaper, PRODUCT_TYPE_PRESS | PRODUCT_TYPE_FEATURE_REFERRAL, "A Positive World"
        );
        productRegistry.updateMetadata(
            _getProductIds().pEthccDemo,
            PRODUCT_TYPE_PRESS | PRODUCT_TYPE_FEATURE_REFERRAL | PRODUCT_TYPE_DAPP,
            "Frak - EthCC demo"
        );

        vm.stopBroadcast();
    }
}
