// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {CONTENT_TYPE_PRESS, ContentTypes} from "src/constants/ContentTypes.sol";
import {INTERCATION_VALIDATOR_ROLE} from "src/constants/Roles.sol";
import {ContentInteraction} from "src/interaction/ContentInteraction.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";
import {PressInteraction} from "src/interaction/PressInteraction.sol";
import {ContentRegistry} from "src/registry/ContentRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";

contract PressInteractionForkTest is Test {
    uint256 private arbSepoliaFork;
    address private owner = 0x7caF754C934710D7C73bc453654552BEcA38223F;

    function setUp() public {
        arbSepoliaFork = vm.createFork(vm.envString("ARBITRUM_SEPOLIA_RPC_URL"), 51832921);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Generic test function                           */
    /* -------------------------------------------------------------------------- */
    // Validation type hash
    bytes32 private constant _VALIDATE_INTERACTION_TYPEHASH =
        keccak256("ValidateInteraction(uint256 contentId,bytes32 interactionData,address user,uint256 nonce)");

    function test_signature() public {
        vm.skip(true);
        vm.selectFork(arbSepoliaFork);

        // Get our interaction manager
        ContentInteractionManager contentInteractionManager =
            ContentInteractionManager(0xfB31dA57Aa2BDb0220d8e189E0a08b0cc55Ee186);

        // The var required for the test
        bytes32 articleId = 0;
        uint256 contentId = 61412812549033025435811962204424170589965658763482764336017940556663446417829; // wired content
        address user = 0x001428331B4d318833c5E1Ec7730D6DBb58b76E3;

        address targetPressInteraction = contentInteractionManager.getInteractionContract(contentId);
        PressInteraction newImplem =
            new PressInteraction(contentId, address(0x0a1d4292bC42d39e02b98A6AF9d2E49F16DBED43));
        vm.etch(targetPressInteraction, address(newImplem).code);

        // And get the interaction contract
        PressInteraction pressInteraction = PressInteraction(targetPressInteraction);
        vm.label(targetPressInteraction, "PressInteraction");

        bytes memory newSignature;

        // Rebuild our data and signature
        {
            bytes32 iterData = keccak256(
                abi.encode(0xc0a24ffb7afa254ad3052f8f1da6e4268b30580018115d9c10b63352b0004b2d, articleId, address(0))
            );
            uint256 nonce = pressInteraction.getNonceForInteraction(iterData, user);
            bytes32 domainSeparator = pressInteraction.getDomainSeparator();

            // Build the digest
            bytes32 dataHash = keccak256(abi.encode(_VALIDATE_INTERACTION_TYPEHASH, contentId, iterData, user, nonce));
            bytes32 fullHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, dataHash));
            console.log("Eip712 hash");
            console.logBytes32(fullHash);

            // Sign the full hash
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xdeadbeef, fullHash);
            if (v != 27) {
                // then left-most bit of s has to be flipped to 1.
                s = s | bytes32(uint256(1) << 255);
            }

            // Compact the signature into a single byte
            newSignature = abi.encodePacked(r, s);
            console.log("Signature");
            console.logBytes(newSignature);
        }
        vm.prank(user);
        pressInteraction.articleOpened(articleId, newSignature);
        return;
    }
}

// 0x00000000000000000000000047d0ad240674946db3e48706ebc286e7eb0ae1d4
