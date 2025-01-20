// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, DeterminedAddress} from "./DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {CampaignFactory} from "src/campaign/CampaignFactory.sol";
import {
    PRODUCT_TYPE_DAPP,
    PRODUCT_TYPE_FEATURE_REFERRAL,
    PRODUCT_TYPE_PRESS,
    ProductTypes
} from "src/constants/ProductTypes.sol";
import {InteractionFacetsFactory} from "src/interaction/InteractionFacetsFactory.sol";
import {ProductInteractionManager} from "src/interaction/ProductInteractionManager.sol";
import {ICampaignFactory} from "src/interfaces/ICampaignFactory.sol";
import {PurchaseOracle} from "src/oracle/PurchaseOracle.sol";
import {ProductAdministratorRegistry} from "src/registry/ProductAdministratorRegistry.sol";
import {ProductRegistry} from "src/registry/ProductRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";

/// @dev update our smart contracts
contract Update is Script, DeterminedAddress {
    function run() public {
        Addresses memory addresses = _getAddresses();

        // _updateProductInteractionManager(addresses);
        // _updateFacetFactory(addresses);
        _updateCampaignsFactory(addresses);

        // Save the addresses in a json file
        _saveAddresses(addresses);
    }

    function _updateProductInteractionManager(Addresses memory addresses) internal {
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

    function _updateFacetFactory(Addresses memory addresses) internal {
        ProductInteractionManager productInteractionManager =
            ProductInteractionManager(addresses.productInteractionManager);

        vm.startBroadcast();

        // Deploy the facet factory
        InteractionFacetsFactory facetFactory = new InteractionFacetsFactory{salt: bytes32(uint256(1312))}(
            ReferralRegistry(addresses.referralRegistry),
            ProductRegistry(addresses.productRegistry),
            ProductAdministratorRegistry(addresses.productAdministratorRegistry),
            PurchaseOracle(addresses.purchaseOracle)
        );
        console.log("New facet factory: ", address(facetFactory));

        // update the facet factory
        productInteractionManager.updateFacetsFactory(facetFactory);

        vm.stopBroadcast();

        // Update the addresses
        addresses.facetFactory = address(facetFactory);
    }

    function _updateCampaignsFactory(Addresses memory addresses) internal {
        ProductInteractionManager productInteractionManager =
            ProductInteractionManager(addresses.productInteractionManager);

        vm.startBroadcast();

        CampaignFactory campaignFactory = new CampaignFactory{salt: bytes32(uint256(1312))}(
            ReferralRegistry(addresses.referralRegistry),
            ProductAdministratorRegistry(addresses.productAdministratorRegistry)
        );

        console.log("New campaign factory: ", address(campaignFactory));

        // update the campaign factory
        productInteractionManager.updateCampaignFactory(campaignFactory);

        vm.stopBroadcast();

        // Update the addresses
        addresses.campaignFactory = address(campaignFactory);
    }
}
