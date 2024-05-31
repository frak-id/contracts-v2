// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {INTERCATION_VALIDATOR_ROLE} from "src/constants/Roles.sol";
import {ContentInteraction} from "src/interaction/ContentInteraction.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";
import {ContentRegistry} from "src/registry/ContentRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";

/// @dev Generic contract to test interaction
abstract contract InteractionTest is Test {
    address internal owner = makeAddr("owner");
    address internal minter = makeAddr("minter");

    ContentRegistry internal contentRegistry = new ContentRegistry(owner);
    ReferralRegistry internal referralRegistry = new ReferralRegistry(owner);
    ContentInteractionManager internal contentInteractionManager;

    uint256 internal validatorPrivKey;
    address internal validator;

    ContentInteraction internal contentInteraction;

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
        contentInteraction = ContentInteraction(interactionContract);

        // Grant the validator roles
        vm.prank(owner);
        ContentInteraction(interactionContract).grantRoles(validator, INTERCATION_VALIDATOR_ROLE);
    }

    // Validation type hash
    bytes32 private constant _VALIDATE_INTERACTION_TYPEHASH =
        keccak256("ValidateInteraction(uint256 contentId, bytes32 interactionData,address user, uint256 nonce)");

    /// @dev Generate an interaction signature for the given interaction data
    function _getInteractionSignature(bytes32 _interactionData, address _user)
        internal
        view
        returns (bytes memory signature)
    {
        uint256 nonce = contentInteraction.getNonceForInteraction(_interactionData, _user);
        bytes32 domainSeparator = contentInteraction.getDomainSeparator();

        // Build the digest
        bytes32 dataHash = keccak256(
            abi.encode(
                _VALIDATE_INTERACTION_TYPEHASH, contentInteraction.getContentId(), _interactionData, _user, nonce
            )
        );
        bytes32 fullHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, dataHash));

        // Sign the full hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorPrivKey, fullHash);
        if (v != 27) {
            // then left-most bit of s has to be flipped to 1.
            s = s | bytes32(uint256(1) << 255);
        }

        // Compact the signature into a single byte
        signature = abi.encodePacked(r, s);
    }
}
