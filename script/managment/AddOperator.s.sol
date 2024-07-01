// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, ContentIds, DeterminedAddress} from "../DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {InteractionCampaign} from "src/campaign/InteractionCampaign.sol";
import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
import {ContentInteractionDiamond} from "src/interaction/ContentInteractionDiamond.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";

contract AddOperator is Script, DeterminedAddress {
    address private operator = 0x04C799736D1aCfA30a0B952c2be5ADF960d5dDaa;

    function run() public {
        Addresses memory addresses = _getAddresses();

        ContentInteractionManager contentInteractionManager =
            ContentInteractionManager(addresses.contentInteractionManager);

        // Iterate over each content ids, and clean the attached campaigns
        uint256[] memory contentIds = _getContentIdsArr();
        for (uint256 i = 0; i < contentIds.length; i++) {
            uint256 cId = contentIds[i];

            // Get the interaction contract and the active campaigns
            _addOperator(contentInteractionManager, cId);
        }
    }

    function _addOperator(ContentInteractionManager _contentInteractionManager, uint256 _cId) internal {
        vm.startBroadcast();
        _contentInteractionManager.addOperator(_cId, operator);
        vm.stopBroadcast();
    }
}
