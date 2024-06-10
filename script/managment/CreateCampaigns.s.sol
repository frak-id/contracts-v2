// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, ContentIds, DeterminedAddress} from "../DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {InteractionCampaign} from "src/campaign/InteractionCampaign.sol";
import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
import {ContentInteractionDiamond} from "src/interaction/ContentInteractionDiamond.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";
import {PaywallToken} from "src/tokens/PaywallToken.sol";

contract CreateCampaigns is Script, DeterminedAddress {
    address internal interactionValidator = 0x8747C17970464fFF597bd5a580A72fCDA224B0A1;

    function run() public {
        Addresses memory addresses = _getAddresses();

        ContentInteractionManager contentInteractionManager =
            ContentInteractionManager(addresses.contentInteractionManager);

        // Iterate over each content ids, and clean the attached campaigns
        uint256[] memory contentIds = _getContentIdsArr();
        for (uint256 i = 0; i < contentIds.length; i++) {
            uint256 cId = contentIds[i];

            _setupCampaign(contentInteractionManager, cId, addresses);
        }
    }

    function _setupCampaign(ContentInteractionManager _interactionManager, uint256 _cId, Addresses memory _addresses)
        internal
    {
        ContentInteractionDiamond interactionContract = _interactionManager.getInteractionContract(_cId);
        bytes32 tree = interactionContract.getReferralTree();

        vm.startBroadcast();

        ReferralCampaign campaign = _deployCampaign(tree, _addresses);
        _interactionManager.attachCampaign(_cId, campaign);
        PaywallToken(_addresses.paywallToken).transfer(address(campaign), 100_000 ether);

        vm.stopBroadcast();

        console.log("Campaign %s deployed for content %s", address(campaign), _cId);
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
