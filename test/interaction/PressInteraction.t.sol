// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ContentTypes, CONTENT_TYPE_PRESS} from "src/constants/ContentTypes.sol";
import {PressInteraction} from "src/interaction/PressInteraction.sol";
import {INTERCATION_VALIDATOR_ROLE} from "src/constants/Roles.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {InteractionTest} from "./InteractionTest.sol";
import {Test} from "forge-std/Test.sol";
import "forge-std/Console.sol";

contract PressInteractionTest is InteractionTest {
    uint256 internal contentId;

    PressInteraction private pressInteraction;

    function setUp() public {
        // TODO: Setup with a more granular approach
        vm.prank(owner);
        contentId = contentRegistry.mint(CONTENT_TYPE_PRESS, "name", "press-domain");

        // Deploy the press interaction contract
        pressInteraction = PressInteraction(_initInteractionTest(contentId));
    }

    function test_description() public view {
        // TODO: More specific test?
        assertEq(pressInteraction.getContentId(), contentId);
        assertEq(ContentTypes.unwrap(pressInteraction.getContentType()), ContentTypes.unwrap(CONTENT_TYPE_PRESS));

        assertNotEq(pressInteraction.getReferralTree(), bytes32(0));
        bytes32 computedReferralTree = keccak256(abi.encodePacked(keccak256("ContentReferralTree"), contentId));
        assertEq(pressInteraction.getReferralTree(), computedReferralTree);
    }

    function test_domainSeparator() public view {
        // TODO: More specific test?
        assertNotEq(pressInteraction.getDomainSeparator(), bytes32(0));
    }
}
