// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InteractionTest} from "./InteractionTest.sol";

import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {CONTENT_TYPE_PRESS, ContentTypes} from "src/constants/ContentTypes.sol";
import {INTERCATION_VALIDATOR_ROLE} from "src/constants/Roles.sol";
import {PressInteraction} from "src/interaction/PressInteraction.sol";

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

    /* -------------------------------------------------------------------------- */
    /*                              Test open article                             */
    /* -------------------------------------------------------------------------- */

    function test_openArticle() public {}

    /* -------------------------------------------------------------------------- */
    /*                                 Sig helpers                                */
    /* -------------------------------------------------------------------------- */

    function _openArticleData(uint256 _articleId, uint256 _shareId) private pure returns (bytes32) {
        return keccak256(
            abi.encode(0xc0a24ffb7afa254ad3052f8f1da6e4268b30580018115d9c10b63352b0004b2d, _articleId, _shareId)
        );
    }

    function _readArticleData(uint256 _articleId) private pure returns (bytes32) {
        return keccak256(abi.encode(0xd5bd0fbe3510f2dde55a90e8bb325735d540cc475e1875f00abfd5a81015b073, _articleId));
    }

    function _createShareLinkData(uint256 _articleId) private pure returns (bytes32) {
        return keccak256(abi.encode(0xaf75a9c1cea9f66971d8d341459fd474beb48c11cce7f5962860bec428704d98, _articleId));
    }
}
