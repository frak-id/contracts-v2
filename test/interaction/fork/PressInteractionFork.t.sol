// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Addresses, DeterminedAddress} from "script/DeterminedAddress.sol";
import {CONTENT_TYPE_PRESS, ContentTypes, DENOMINATOR_DAPP, DENOMINATOR_PRESS} from "src/constants/ContentTypes.sol";
import {InteractionType, InteractionTypeLib, PressInteractions} from "src/constants/InteractionType.sol";
import {INTERCATION_VALIDATOR_ROLE, REFERRAL_ALLOWANCE_MANAGER_ROLE} from "src/constants/Roles.sol";
import {ContentInteractionDiamond} from "src/interaction/ContentInteractionDiamond.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";

contract PressInteractionForkTest is Test, DeterminedAddress {
    uint256 private arbSepoliaFork;

    ContentInteractionManager internal contentInteractionManager;
    ContentInteractionDiamond internal contentInteraction;

    address private owner = 0x7caF754C934710D7C73bc453654552BEcA38223F;
    uint256 internal validatorPrivKey;
    address internal validator;

    uint256 private contentId = _getContentIds().cFrak;

    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");
    address private charlie = makeAddr("charlie");

    function setUp() public {
        // Create our forks
        arbSepoliaFork = vm.createFork(vm.envString("ARBITRUM_SEPOLIA_RPC_URL"), _getDeploymentBlocks().arbSepolia);

        // Create our validator ECDSA
        (validator, validatorPrivKey) = makeAddrAndKey("validator");
    }

    function test_readArticle() public arbSepoliaEnv {
        // Prepare our tx
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(PressInteractions.READ_ARTICLE, abi.encode(bytes32(0)), alice);
        // Call the open article method
        vm.prank(alice);
        contentInteraction.handleInteraction(packedInteraction, signature);
    }

    function test_openArticle() public arbSepoliaEnv {
        // Prepare our tx
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(PressInteractions.OPEN_ARTICLE, abi.encode(bytes32(0)), alice);
        // Call the open article method
        vm.prank(alice);
        contentInteraction.handleInteraction(packedInteraction, signature);
    }

    function test_referred() public arbSepoliaEnv {
        // Prepare our tx
        (bytes memory packedInteraction, bytes memory signature) =
            _prepareInteraction(PressInteractions.REFERRED, abi.encode(charlie), bob);
        // Call the open article method
        vm.prank(bob);
        contentInteraction.handleInteraction(packedInteraction, signature);

        // Prepare our tx
        (packedInteraction, signature) = _prepareInteraction(PressInteractions.REFERRED, abi.encode(bob), alice);
        // Call the open article method
        vm.prank(alice);
        contentInteraction.handleInteraction(packedInteraction, signature);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Signature utils                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Generate an interaction signature for the given interaction data
    function _getInteractionSignature(bytes memory _interactionData, address _user)
        internal
        view
        returns (bytes memory signature)
    {
        uint256 nonce = contentInteraction.getNonceForInteraction(keccak256(_interactionData), _user);
        bytes32 domainSeparator = contentInteraction.getDomainSeparator();

        // Build the digest
        bytes32 dataHash = keccak256(
            abi.encode(
                keccak256("ValidateInteraction(uint256 contentId,bytes32 interactionData,address user,uint256 nonce)"),
                contentId,
                keccak256(_interactionData),
                _user,
                nonce
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

    function _prepareInteraction(InteractionType action, bytes memory interactionData, address user)
        internal
        returns (bytes memory data, bytes memory signature)
    {
        vm.pauseGasMetering();
        bytes memory facetData = abi.encodePacked(action, interactionData);
        data = abi.encodePacked(DENOMINATOR_PRESS, facetData);
        signature = _getInteractionSignature(facetData, user);
        vm.resumeGasMetering();
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Fork utils                                 */
    /* -------------------------------------------------------------------------- */

    modifier arbSepoliaEnv() {
        vm.selectFork(arbSepoliaFork);

        Addresses memory addresses = _getAddresses();
        contentInteractionManager = ContentInteractionManager(addresses.contentInteractionManager);
        contentInteraction = contentInteractionManager.getInteractionContract(contentId);

        // Grant the validator roles
        vm.prank(owner);
        contentInteraction.grantRoles(validator, INTERCATION_VALIDATOR_ROLE);

        _;
    }
}
