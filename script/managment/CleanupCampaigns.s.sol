// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, DeterminedAddress, ProductIds} from "../DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {InteractionCampaign} from "src/campaign/InteractionCampaign.sol";
import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";
import {ProductInteractionManager} from "src/interaction/ProductInteractionManager.sol";

contract CleanupCampaigns is Script, DeterminedAddress {
    function run() public {
        Addresses memory addresses = _getAddresses();

        ProductInteractionManager productInteractionManager =
            ProductInteractionManager(addresses.productInteractionManager);

        // Iterate over each product ids, and clean the attached campaigns
        uint256[] memory productIds = _getProductIdsArr();
        for (uint256 i = 0; i < productIds.length; i++) {
            uint256 cId = productIds[i];

            // Get the interaction contract and the active campaigns
            ProductInteractionDiamond interactionContract = productInteractionManager.getInteractionContract(cId);
            InteractionCampaign[] memory campaigns = interactionContract.getCampaigns();

            // Clean them up
            _cleanInteractionCampaigns(campaigns);

            // Detach them
            _detachCampaigns(productInteractionManager, cId, campaigns);
        }
    }

    /// @dev Mint a product with the given name and domain
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
        vm.startBroadcast();
        _campaign.withdraw();
        vm.stopBroadcast();
    }

    function _detachCampaigns(
        ProductInteractionManager _productInteractionManager,
        uint256 _cId,
        InteractionCampaign[] memory _campaigns
    ) internal {
        vm.startBroadcast();
        _productInteractionManager.detachCampaigns(_cId, _campaigns);
        vm.stopBroadcast();
    }
}
