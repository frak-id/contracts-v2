// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, ContentIds, DeterminedAddress} from "./DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
import {CONTENT_TYPE_PRESS, ContentTypes} from "src/constants/ContentTypes.sol";
import {Paywall} from "src/gating/Paywall.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";
import {InteractionFacetsFactory} from "src/interaction/InteractionFacetsFactory.sol";
import {ICampaignFactory} from "src/interfaces/ICampaignFactory.sol";
import {ContentRegistry} from "src/registry/ContentRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";
import {PaywallToken} from "src/tokens/PaywallToken.sol";

/// todo: Should be refacto to update the faucet factory, set it on the contentInteractionManager, and then call the update function
contract UpdateContentInteractions is Script, DeterminedAddress {
    function run() public {
        // _updateManager();
        //_updateInteractions();
        _updateCampaigns();
    }

    function _updateManager() internal {
        Addresses memory addresses = _getAddresses();

        ContentInteractionManager currentManager = ContentInteractionManager(addresses.contentInteractionManager);

        vm.startBroadcast();

        address newImplem = address(
            new ContentInteractionManager{salt: 0}(
                ContentRegistry(addresses.contentRegistry), ReferralRegistry(addresses.referralRegistry)
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
        contentInteractionManager.updateInteractionContract(contentIds.cLeMonde);
        contentInteractionManager.updateInteractionContract(contentIds.cLequipe);
        contentInteractionManager.updateInteractionContract(contentIds.cWired);
        contentInteractionManager.updateInteractionContract(contentIds.cFrak);
        contentInteractionManager.updateInteractionContract(contentIds.cFrakDapp);

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
}
