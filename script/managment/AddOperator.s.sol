// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Addresses, ContentIds, DeterminedAddress} from "../DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {InteractionCampaign} from "src/campaign/InteractionCampaign.sol";
import {ReferralCampaign} from "src/campaign/ReferralCampaign.sol";
import {MINTER_ROLE} from "src/constants/Roles.sol";
import {ContentInteractionDiamond} from "src/interaction/ContentInteractionDiamond.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";
import {ContentRegistry} from "src/registry/ContentRegistry.sol";

contract AddOperator is Script, DeterminedAddress {
    address private operator = 0x286AD1b2A0d94Bd64f260f60b0A17Ea02b8fD8FE;

    address private contentMinter = 0x35F3e191523C8701aD315551dCbDcC5708efD7ec;

    function run() public {
        Addresses memory addresses = _getAddresses();

        //_addContentMinter(ContentRegistry(addresses.contentRegistry));
        //return;

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

    function _addContentMinter(ContentRegistry _contentRegistry) internal {
        vm.startBroadcast();
        _contentRegistry.grantRoles(contentMinter, MINTER_ROLE);
        vm.stopBroadcast();
    }
}
