// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {CAMPAIGN_EVENT_EMITTER_ROLE, MockCampaign} from "../utils/MockCampaign.sol";
import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {InteractionType, InteractionTypeLib, PressInteractions} from "src/constants/InteractionType.sol";
import {INTERCATION_VALIDATOR_ROLE, REFERRAL_ALLOWANCE_MANAGER_ROLE} from "src/constants/Roles.sol";
import {ContentInteractionDiamond} from "src/interaction/ContentInteractionDiamond.sol";
import {ContentInteractionManager} from "src/interaction/ContentInteractionManager.sol";

import {InteractionFacetsFactory} from "src/interaction/InteractionFacetsFactory.sol";
import {ContentRegistry} from "src/registry/ContentRegistry.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";

/// @dev Generic contract to test interaction
abstract contract InteractionTest is Test {
    uint256 internal contentId;

    address internal owner = makeAddr("owner");
    address internal operator = makeAddr("operator");

    ContentRegistry internal contentRegistry = new ContentRegistry(owner);
    ReferralRegistry internal referralRegistry = new ReferralRegistry(owner);
    ContentInteractionManager internal contentInteractionManager;
    InteractionFacetsFactory internal facetFactory;

    uint256 internal validatorPrivKey;
    address internal validator;

    ContentInteractionDiamond internal contentInteraction;

    /// @dev A few mocked campaign
    MockCampaign internal campaign1;
    MockCampaign internal campaign2;
    MockCampaign internal campaign3;
    MockCampaign internal campaign4;

    function _initInteractionTest() internal {
        // Create our validator ECDSA
        (validator, validatorPrivKey) = makeAddrAndKey("validator");

        facetFactory = new InteractionFacetsFactory(referralRegistry, contentRegistry);

        // Create our content interaction
        address implem = address(new ContentInteractionManager(contentRegistry, referralRegistry));
        address proxy = LibClone.deployERC1967(implem);
        contentInteractionManager = ContentInteractionManager(proxy);
        contentInteractionManager.init(owner, facetFactory);

        // Grant the right roles to the content interaction manager
        vm.prank(owner);
        referralRegistry.grantRoles(address(contentInteractionManager), REFERRAL_ALLOWANCE_MANAGER_ROLE);

        // Deploy the interaction contract
        vm.prank(operator);
        contentInteractionManager.deployInteractionContract(contentId);
        contentInteraction = contentInteractionManager.getInteractionContract(contentId);
        vm.label(address(contentInteraction), "ContentInteractionDiamond");

        // Grant the validator roles
        vm.prank(owner);
        contentInteraction.grantRoles(validator, INTERCATION_VALIDATOR_ROLE);

        // Craft each cmapaign
        campaign1 = new MockCampaign(owner, address(contentInteractionManager));
        campaign2 = new MockCampaign(owner, address(contentInteractionManager));
        campaign3 = new MockCampaign(owner, address(contentInteractionManager));
        campaign4 = new MockCampaign(owner, address(contentInteractionManager));
    }

    // Validation type hash
    bytes32 private constant _VALIDATE_INTERACTION_TYPEHASH = keccak256(
        "ValidateInteraction(uint256 contentId,bytes32 interactionData,address user,uint256 nonce)"
    );

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
            abi.encode(_VALIDATE_INTERACTION_TYPEHASH, contentId, keccak256(_interactionData), _user, nonce)
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

    function _packInteraction(uint8 contentTypeDenominator, InteractionType action, bytes memory interactionData)
        internal
        pure
        returns (bytes memory data)
    {
        data = abi.encodePacked(contentTypeDenominator, action, interactionData);
    }

    function _prepareInteraction(
        uint8 contentTypeDenominator,
        InteractionType action,
        bytes memory interactionData,
        address user
    ) internal returns (bytes memory data, bytes memory signature) {
        vm.pauseGasMetering();
        bytes memory facetData = abi.encodePacked(action, interactionData);
        data = abi.encodePacked(contentTypeDenominator, facetData);
        signature = _getInteractionSignature(facetData, user);
        vm.resumeGasMetering();
    }

    /* -------------------------------------------------------------------------- */
    /*                  Asbtract function to generate a few tests                 */
    /* -------------------------------------------------------------------------- */

    /// @dev Perform some event with interaction
    function performSingleInteraction() internal virtual;

    /* -------------------------------------------------------------------------- */
    /*                             Some generic tests                             */
    /* -------------------------------------------------------------------------- */

    function test_singleCampaign() public withSingleCampaign {
        performSingleInteraction();

        assertEq(campaign1.getInteractionHandled(), 1);
    }

    function test_multiCampaign() public withMultiCampaign {
        performSingleInteraction();

        assertEq(campaign1.getInteractionHandled(), 1);
        assertEq(campaign2.getInteractionHandled(), 1);
        assertEq(campaign3.getInteractionHandled(), 1);
        assertEq(campaign4.getInteractionHandled(), 1);
    }

    function test_multiFailingCampaign() public withFailingCampaign {
        performSingleInteraction();

        assertEq(campaign1.getInteractionHandled(), 1);
        assertEq(campaign2.getInteractionHandled(), 0);
        assertEq(campaign3.getInteractionHandled(), 0);
        assertEq(campaign4.getInteractionHandled(), 1);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Utils modifier                               */
    /* -------------------------------------------------------------------------- */

    modifier withSingleCampaign() {
        vm.prank(operator);
        contentInteractionManager.attachCampaign(contentId, campaign1);
        _;
    }

    modifier withMultiCampaign() {
        vm.startPrank(operator);
        contentInteractionManager.attachCampaign(contentId, campaign1);
        contentInteractionManager.attachCampaign(contentId, campaign2);
        contentInteractionManager.attachCampaign(contentId, campaign3);
        contentInteractionManager.attachCampaign(contentId, campaign4);
        vm.stopPrank();
        _;
    }

    modifier withFailingCampaign() {
        campaign2.setFail(true);
        campaign3.setFail(true);

        vm.startPrank(operator);
        contentInteractionManager.attachCampaign(contentId, campaign1);
        contentInteractionManager.attachCampaign(contentId, campaign2);
        contentInteractionManager.attachCampaign(contentId, campaign3);
        contentInteractionManager.attachCampaign(contentId, campaign4);
        vm.stopPrank();
        _;
    }
}
