// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, ContentIds, DeterminedAddress} from "./DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
import {CONTENT_TYPE_PRESS, ContentTypes} from "src/constants/ContentTypes.sol";
import {Paywall} from "src/gating/Paywall.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";
import {ContentRegistry} from "src/registry/ContentRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";
import {PaywallToken} from "src/tokens/PaywallToken.sol";

/// todo: Should be refacto to update the faucet factory, set it on the contentInteractionManager, and then call the update function
contract UpdateContentInteractions is Script, DeterminedAddress {
    function run() public {
        updateManager();
        updateInteractions();
    }

    function updateManager() internal {
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

    function updateInteractions() internal {
        ContentIds memory contentIds = _getContentIds();
        Addresses memory addresses = _getAddresses();

        ContentInteractionManager contentInteractionManager =
            ContentInteractionManager(addresses.contentInteractionManager);

        vm.startBroadcast();

        // Update the interaction contracts
        contentInteractionManager.updateInteractionContract(contentIds.cLeMonde);
        contentInteractionManager.updateInteractionContract(contentIds.cLequipe);
        contentInteractionManager.updateInteractionContract(contentIds.cWired);
        contentInteractionManager.updateInteractionContract(contentIds.cFrak);

        vm.stopBroadcast();
    }
}
