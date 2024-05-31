// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ContentRegistry} from "src/registry/ContentRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";
import {ContentInteraction} from "src/interaction/ContentInteraction.sol";
import {INTERCATION_VALIDATOR_ROLE} from "src/constants/Roles.sol";
import {Test} from "forge-std/Test.sol";
import "forge-std/Console.sol";

/// @dev Generic contract to test interaction
abstract contract InteractionTest is Test {
    address internal owner = makeAddr("owner");
    address internal minter = makeAddr("minter");

    ContentRegistry internal contentRegistry = new ContentRegistry(owner);
    ReferralRegistry internal referralRegistry = new ReferralRegistry(owner);
    ContentInteractionManager internal contentInteractionManager;

    uint256 internal validatorPrivKey;
    address internal validator;

    function _initInteractionTest(uint256 contentId) internal returns (address interactionContract) {
        // Create our validator ECDSA
        (validator, validatorPrivKey) = makeAddrAndKey("validator");

        // Create our content interaction
        address implem = address(new ContentInteractionManager(contentRegistry, referralRegistry));
        address proxy = LibClone.deployERC1967(implem);
        contentInteractionManager = ContentInteractionManager(proxy);
        contentInteractionManager.init(owner);

        // Deploy the interaction contract
        contentInteractionManager.deployInteractionContract(contentId);
        interactionContract = contentInteractionManager.getInteractionContract(contentId);

        // Grant the validator roles
        vm.prank(owner);
        ContentInteraction(interactionContract).grantRoles(validator, INTERCATION_VALIDATOR_ROLE);
    }
}
