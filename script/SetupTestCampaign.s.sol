// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, ContentIds, DeterminedAddress} from "./DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
import {ContentInteractionDiamond} from "src/interaction/ContentInteractionDiamond.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";
import {PaywallToken} from "src/tokens/PaywallToken.sol";

contract SetupTestCampaign is Script, DeterminedAddress {
    function run() public {
        setupContents();
    }

    function setupContents() internal {
        ContentIds memory contentIds = _getContentIds();
        Addresses memory addresses = _getAddresses();

        ContentInteractionManager contentInteractionManager =
            ContentInteractionManager(addresses.contentInteractionManager);

        vm.startBroadcast();

        // Get our referral trees
        bytes32 leMondeTree = ContentInteractionDiamond(
            contentInteractionManager.getInteractionContract(contentIds.cLeMonde)
        ).getReferralTree();
        bytes32 lequipeTree = ContentInteractionDiamond(
            contentInteractionManager.getInteractionContract(contentIds.cLequipe)
        ).getReferralTree();
        bytes32 wiredTree = ContentInteractionDiamond(
            contentInteractionManager.getInteractionContract(contentIds.cWired)
        ).getReferralTree();

        // Create each campaigns
        ReferralCampaign leMondeCampaign = _deployCampaign(leMondeTree, addresses);
        ReferralCampaign lequipeCampaign = _deployCampaign(lequipeTree, addresses);
        ReferralCampaign wiredCampaign = _deployCampaign(wiredTree, addresses);

        // Deploy the interaction contracts
        contentInteractionManager.attachCampaign(contentIds.cLeMonde, leMondeCampaign);
        contentInteractionManager.attachCampaign(contentIds.cLequipe, lequipeCampaign);
        contentInteractionManager.attachCampaign(contentIds.cWired, wiredCampaign);

        // Mint a few pFrk to every campaign
        PaywallToken(addresses.paywallToken).mint(address(leMondeCampaign), 100_000 ether);
        PaywallToken(addresses.paywallToken).mint(address(lequipeCampaign), 100_000 ether);
        PaywallToken(addresses.paywallToken).mint(address(wiredCampaign), 100_000 ether);

        vm.stopBroadcast();
    }

    function _deployCampaign(bytes32 tree, Addresses memory addresses) private returns (ReferralCampaign) {
        return new ReferralCampaign{salt: tree}(
            addresses.paywallToken, // token
            5, // exploration level
            2_000, // per level distribution (on 1/10_000), so here 20%
            10 ether, // Initial referral reward
            500 ether, // Daily distribution cap
            tree, // referralTree
            ReferralRegistry(addresses.referralRegistry), // referralRegistry
            msg.sender, // owner
            addresses.contentInteractionManager
        );
    }
}
