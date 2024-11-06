// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, DeterminedAddress} from "./DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
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
import {PurchaseOracle} from "src/oracle/PurchaseOracle.sol";

/// @dev update our smart contracts
contract Update is Script, DeterminedAddress {
    function run() public {
        _updateProductInteractionManager();
        _updateFacetFactory();
        // _updateCampaignsFactory();
    }

    function _updateProductInteractionManager() internal {
        Addresses memory addresses = _getAddresses();

        ProductInteractionManager currentManager = ProductInteractionManager(addresses.productInteractionManager);

        vm.startBroadcast();

        address newImplem = address(
            new ProductInteractionManager{salt: 0xae4e57b886541829ba70efc84340653c41e2908c37ddbb1a8cdb7800db7afab8}(
                ProductRegistry(addresses.productRegistry),
                ReferralRegistry(addresses.referralRegistry),
                ProductAdministratorRegistry(addresses.productAdministratorRegistry)
            )
        );
        console.log("New implementation address: ", newImplem);
        currentManager.upgradeToAndCall(newImplem, "");

        vm.stopBroadcast();
    }

    function _updateFacetFactory() internal {
        Addresses memory addresses = _getAddresses();

        ProductInteractionManager productInteractionManager =
            ProductInteractionManager(addresses.productInteractionManager);

        vm.startBroadcast();

        // Deploy the facet factory
        InteractionFacetsFactory facetFactory = new InteractionFacetsFactory{
            salt: 0xae4e57b886541829ba70efc84340653c41e2908c4b2e2db998fc48004e5ce2af
        }(
            ReferralRegistry(addresses.referralRegistry),
            ProductRegistry(addresses.productRegistry),
            ProductAdministratorRegistry(addresses.productAdministratorRegistry),
            PurchaseOracle(addresses.purchaseOracle)
        );
        console.log("New facet factory: ", address(facetFactory));

        // update the facet factory
        productInteractionManager.updateFacetsFactory(facetFactory);

        vm.stopBroadcast();
    }

    function _updateCampaignsFactory() internal {
        Addresses memory addresses = _getAddresses();

        ProductInteractionManager productInteractionManager =
            ProductInteractionManager(addresses.productInteractionManager);

        vm.startBroadcast();

        // update the campaign factory
        productInteractionManager.updateCampaignFactory(ICampaignFactory(addresses.campaignFactory));

        vm.stopBroadcast();
    }
}
