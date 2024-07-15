// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, ContentIds, DeterminedAddress} from "../DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {InteractionCampaign} from "src/campaign/InteractionCampaign.sol";
import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
import {ContentInteractionDiamond} from "src/interaction/ContentInteractionDiamond.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";

contract CleanupCampaigns is Script, DeterminedAddress {
    function run() public {
        Addresses memory addresses = _getAddresses();

        ContentInteractionManager contentInteractionManager =
            ContentInteractionManager(addresses.contentInteractionManager);

        // Iterate over each content ids, and clean the attached campaigns
        uint256[] memory contentIds = _getContentIdsArr();
        for (uint256 i = 0; i < contentIds.length; i++) {
            uint256 cId = contentIds[i];

            // Get the interaction contract and the active campaigns
            ContentInteractionDiamond interactionContract = contentInteractionManager.getInteractionContract(cId);
            InteractionCampaign[] memory campaigns = interactionContract.getCampaigns();

            // Clean them up
            _cleanInteractionCampaigns(campaigns);

            // Detach them
            _detachCampaigns(contentInteractionManager, cId, campaigns);
        }
    }

    /// @dev Mint a content with the given name and domain
    function _cleanInteractionCampaigns(InteractionCampaign[] memory _campaigns) internal {
        bytes32 referralIdentifier = keccak256("frak.campaign.referral");

        // Iterate over each campaign
        for (uint256 i = 0; i < _campaigns.length; i++) {
            InteractionCampaign campaign = _campaigns[i];
            (string memory name,) = campaign.getMetadata();

            // If it's a referral campaign, clean it up
            if (keccak256(bytes(name)) == referralIdentifier) {
                _cleanupReferralCampaign(ReferralCampaign(address(campaign)));
            }
        }
    }

    function _cleanupReferralCampaign(ReferralCampaign _campaign) internal {
        console.log("Witdrawing campaign %s token", address(_campaign));
        address campaignAddress = address(_campaign);
        vm.startBroadcast();
        _campaign.withdraw();
        vm.stopBroadcast();
    }

    function _detachCampaigns(
        ContentInteractionManager _contentInteractionManager,
        uint256 _cId,
        InteractionCampaign[] memory _campaigns
    ) internal {
        vm.startBroadcast();
        _contentInteractionManager.detachCampaigns(_cId, _campaigns);
        vm.stopBroadcast();
    }
}
