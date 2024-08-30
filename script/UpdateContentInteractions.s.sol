// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, ContentIds, DeterminedAddress} from "./DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
import {
    CONTENT_TYPE_DAPP,
    CONTENT_TYPE_FEATURE_REFERRAL,
    CONTENT_TYPE_PRESS,
    ContentTypes
} from "src/constants/ContentTypes.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";
import {InteractionFacetsFactory} from "src/interaction/InteractionFacetsFactory.sol";
import {ICampaignFactory} from "src/interfaces/ICampaignFactory.sol";
import {ContentRegistry} from "src/registry/ContentRegistry.sol";
import {ProductAdministratorRegistry} from "src/registry/ProductAdministratorRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";

/// todo: Should be refacto to update the faucet factory, set it on the contentInteractionManager, and then call the update function
contract UpdateContentInteractions is Script, DeterminedAddress {
    function run() public {
        // _updateManager();
        //_updateContents();
        //_updateInteractions();
        _updateCampaigns();
    }

    function _updateManager() internal {
        Addresses memory addresses = _getAddresses();

        ContentInteractionManager currentManager = ContentInteractionManager(addresses.contentInteractionManager);

        vm.startBroadcast();

        address newImplem = address(
            new ContentInteractionManager{salt: 0}(
                ContentRegistry(addresses.contentRegistry),
                ReferralRegistry(addresses.referralRegistry),
                ProductAdministratorRegistry(addresses.productAdministratorlRegistry)
            )
        );
        currentManager.upgradeToAndCall(newImplem, "");

        vm.stopBroadcast();
    }

    function _updateInteractions() internal {
        ContentIds memory contentIds = _getContentIds();
        Addresses memory addresses = _getAddresses();

        ContentInteractionManager contentInteractionManager =
            ContentInteractionManager(addresses.contentInteractionManager);

        vm.startBroadcast();

        // update the facet factory
        contentInteractionManager.updateFacetsFactory(InteractionFacetsFactory(addresses.facetFactory));

        // Update the interaction contracts
        contentInteractionManager.updateInteractionContract(contentIds.cNewsPaper);
        contentInteractionManager.updateInteractionContract(contentIds.cNewsExample);
        contentInteractionManager.updateInteractionContract(contentIds.cEthccDemo);

        vm.stopBroadcast();
    }

    function _updateCampaigns() internal {
        Addresses memory addresses = _getAddresses();

        ContentInteractionManager contentInteractionManager =
            ContentInteractionManager(addresses.contentInteractionManager);

        vm.startBroadcast();

        // update the campaign factory
        contentInteractionManager.updateCampaignFactory(ICampaignFactory(addresses.campaignFactory));

        vm.stopBroadcast();
    }

    function _updateContents() internal {
        Addresses memory addresses = _getAddresses();

        ContentRegistry contentRegistry = ContentRegistry(addresses.contentRegistry);

        vm.startBroadcast();

        // Update each contents
        contentRegistry.updateMetadata(
            _getContentIds().cNewsPaper, CONTENT_TYPE_PRESS | CONTENT_TYPE_FEATURE_REFERRAL, "A Positivie World"
        );
        contentRegistry.updateMetadata(
            _getContentIds().cNewsExample, CONTENT_TYPE_PRESS | CONTENT_TYPE_FEATURE_REFERRAL, "Frak - Gating Example"
        );
        contentRegistry.updateMetadata(
            _getContentIds().cEthccDemo,
            CONTENT_TYPE_PRESS | CONTENT_TYPE_FEATURE_REFERRAL | CONTENT_TYPE_DAPP,
            "Frak - EthCC demo"
        );

        vm.stopBroadcast();
    }
}
