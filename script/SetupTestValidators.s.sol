// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ContentIds, DeterminedAddress} from "./DeterminedAddress.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import {INTERCATION_VALIDATOR_ROLE} from "src/constants/Roles.sol";
import {ContentInteractionDiamond} from "src/interaction/ContentInteractionDiamond.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";

contract SetupTestContents is Script, DeterminedAddress {
    function run() public {
        ContentInteractionManager contentInteractionManager =
            ContentInteractionManager(_getAddresses().contentInteractionManager);

        ContentIds memory contentIds = _getContentIds();

        vm.startBroadcast();

        // Grant the right roles
        _grantValidatorRole(contentInteractionManager, contentIds.cLeMonde);
        _grantValidatorRole(contentInteractionManager, contentIds.cLequipe);
        _grantValidatorRole(contentInteractionManager, contentIds.cWired);
        _grantValidatorRole(contentInteractionManager, contentIds.cFrak);

        vm.stopBroadcast();
    }

    /// @dev Mint a content with the given name and domain
    function _grantValidatorRole(ContentInteractionManager _contentInteractionManager, uint256 _contentId) internal {
        ContentInteractionDiamond interactionContract = _contentInteractionManager.getInteractionContract(_contentId);
        interactionContract.grantRoles(0x8747C17970464fFF597bd5a580A72fCDA224B0A1, INTERCATION_VALIDATOR_ROLE);
    }
}
