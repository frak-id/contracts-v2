// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {EcosystemAwareTest} from "../EcosystemAwareTest.sol";
import {MockCampaign} from "../utils/MockCampaign.sol";
import {InteractionCampaign} from "src/campaign/InteractionCampaign.sol";
import {InteractionType, InteractionTypeLib, SCOPED_INTERACTION_MARKER} from "src/constants/InteractionType.sol";
import {DENOMINATOR_PRESS, PRODUCT_TYPE_PRESS} from "src/constants/ProductTypes.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";
import {PressInteractions} from "src/constants/InteractionType.sol";
import {INTERACTION_VALIDATOR_ROLE} from "src/constants/Roles.sol";
import {ProductRoles} from "src/registry/ProductAdministratorRegistry.sol";
import "forge-std/Console.sol";

/// @title ScopedCampaignTest
/// @notice Test suite for scoped campaign execution feature
contract ScopedCampaignTest is EcosystemAwareTest {
    using InteractionTypeLib for bytes;

    uint256 private productId;
    ProductInteractionDiamond private diamond;

    uint256 internal validatorPrivKey;
    address internal validator;

    MockCampaign private defaultCampaign1;
    MockCampaign private defaultCampaign2;
    MockCampaign private scopedCampaign1;
    MockCampaign private scopedCampaign2;

    // Test context IDs
    bytes16 private contextNewsletter;
    bytes16 private contextCreator;
    bytes16 private contextWithDefaultCampaigns;

    // Validation type hash
    bytes32 internal constant _VALIDATE_INTERACTION_TYPEHASH =
        keccak256("ValidateInteraction(uint256 productId,bytes32 interactionData,address user)");

    function setUp() public {
        _initEcosystemAwareTest();

        // Create a press product
        productId = _mintProduct(PRODUCT_TYPE_PRESS, "Test Press", "test-press");

        // Deploy interaction contract
        vm.prank(productOwner);
        diamond = productInteractionManager.deployInteractionContract(productId);

        // Create our validator ECDSA
        (validator, validatorPrivKey) = makeAddrAndKey("validator");

        // Grant the validator roles
        vm.prank(productOwner);
        diamond.grantRoles(validator, INTERACTION_VALIDATOR_ROLE);

        // Deploy mock campaigns
        defaultCampaign1 = new MockCampaign(adminRegistry, diamond);
        defaultCampaign2 = new MockCampaign(adminRegistry, diamond);
        scopedCampaign1 = new MockCampaign(adminRegistry, diamond);
        scopedCampaign2 = new MockCampaign(adminRegistry, diamond);

        // Attach default campaigns
        vm.startPrank(productOwner);
        diamond.attachCampaign(InteractionCampaign(address(defaultCampaign1)));
        diamond.attachCampaign(InteractionCampaign(address(defaultCampaign2)));
        vm.stopPrank();

        // Create context IDs (simple 16-byte identifiers)
        contextNewsletter = bytes16(uint128(1));
        contextCreator = bytes16(uint128(2));
        contextWithDefaultCampaigns = bytes16(uint128(3));

        // Attach scoped campaigns
        vm.startPrank(productOwner);
        // Newsletter: only scoped campaign
        diamond.attachScopedCampaign(contextNewsletter, InteractionCampaign(address(scopedCampaign1)));
        
        // Creator: only scoped campaign  
        diamond.attachScopedCampaign(contextCreator, InteractionCampaign(address(scopedCampaign2)));
        
        // Context with default campaigns: attach both default campaigns to this context
        diamond.attachScopedCampaign(contextWithDefaultCampaigns, InteractionCampaign(address(defaultCampaign1)));
        diamond.attachScopedCampaign(contextWithDefaultCampaigns, InteractionCampaign(address(defaultCampaign2)));
        // Also attach a scoped campaign
        diamond.attachScopedCampaign(contextWithDefaultCampaigns, InteractionCampaign(address(scopedCampaign1)));
        vm.stopPrank();
    }



    /* -------------------------------------------------------------------------- */
    /*                      Test scoped campaign management                       */
    /* -------------------------------------------------------------------------- */

    function test_attachScopedCampaign() public view {
        InteractionCampaign[] memory campaigns = diamond.getScopedCampaigns(contextNewsletter);
        assertEq(campaigns.length, 1);
        assertEq(address(campaigns[0]), address(scopedCampaign1));
    }

    function test_attachScopedCampaign_Unauthorized() public {
        address unauthorized = makeAddr("unauthorized");
        MockCampaign newCampaign = new MockCampaign(adminRegistry, diamond);

        vm.prank(unauthorized);
        vm.expectRevert();
        diamond.attachScopedCampaign(contextNewsletter, InteractionCampaign(address(newCampaign)));
    }

    function test_attachScopedCampaign_Duplicate() public {
        vm.prank(productOwner);
        vm.expectRevert(ProductInteractionDiamond.CampaignAlreadyPresent.selector);
        diamond.attachScopedCampaign(contextNewsletter, InteractionCampaign(address(scopedCampaign1)));
    }

    function test_detachScopedCampaign() public {
        vm.prank(productOwner);
        diamond.detachScopedCampaign(contextNewsletter, InteractionCampaign(address(scopedCampaign1)));

        InteractionCampaign[] memory campaigns = diamond.getScopedCampaigns(contextNewsletter);
        assertEq(campaigns.length, 0);
    }

    function test_getScopedCampaigns_MultipleContexts() public view {
        InteractionCampaign[] memory newsletterCampaigns = diamond.getScopedCampaigns(contextNewsletter);
        InteractionCampaign[] memory creatorCampaigns = diamond.getScopedCampaigns(contextCreator);

        assertEq(newsletterCampaigns.length, 1);
        assertEq(creatorCampaigns.length, 1);
        assertEq(address(newsletterCampaigns[0]), address(scopedCampaign1));
        assertEq(address(creatorCampaigns[0]), address(scopedCampaign2));
    }



    /* -------------------------------------------------------------------------- */
    /*                     Test scoped campaign execution                         */
    /* -------------------------------------------------------------------------- */

    function test_scopedExecution_OnlyScopedCampaigns() public {
        // Create interaction data with newsletter context (no default flag)
        bytes memory interaction = _createScopedInteraction(contextNewsletter, PressInteractions.OPEN_ARTICLE);
        bytes memory signature = _signInteraction(interaction);

        // Execute interaction
        diamond.handleInteraction(interaction, signature);

        // Verify only scoped campaign was called
        assertEq(scopedCampaign1.callCount(), 1, "Scoped campaign 1 should be called once");
        assertEq(scopedCampaign2.callCount(), 0, "Scoped campaign 2 should not be called");
        assertEq(defaultCampaign1.callCount(), 0, "Default campaign 1 should not be called");
        assertEq(defaultCampaign2.callCount(), 0, "Default campaign 2 should not be called");
    }

    function test_scopedExecution_WithDefaultCampaigns() public {
        // Create interaction data with context that has both default and scoped campaigns attached
        bytes memory interaction =
            _createScopedInteraction(contextWithDefaultCampaigns, PressInteractions.OPEN_ARTICLE);
        bytes memory signature = _signInteraction(interaction);

        // Execute interaction
        diamond.handleInteraction(interaction, signature);

        // Verify all campaigns attached to this context were called (3 total)
        assertEq(scopedCampaign1.callCount(), 1, "Scoped campaign 1 should be called once");
        assertEq(defaultCampaign1.callCount(), 1, "Default campaign 1 should be called once (attached to context)");
        assertEq(defaultCampaign2.callCount(), 1, "Default campaign 2 should be called once (attached to context)");
        assertEq(scopedCampaign2.callCount(), 0, "Scoped campaign 2 should not be called");
    }

    function test_legacyExecution_OnlyDefaultCampaigns() public {
        // Create legacy interaction data (no contextId)
        bytes memory interaction = _createLegacyInteraction(PressInteractions.OPEN_ARTICLE);
        bytes memory signature = _signInteraction(interaction);

        // Execute interaction
        diamond.handleInteraction(interaction, signature);

        // Verify only default campaigns were called
        assertEq(defaultCampaign1.callCount(), 1, "Default campaign 1 should be called once");
        assertEq(defaultCampaign2.callCount(), 1, "Default campaign 2 should be called once");
        assertEq(scopedCampaign1.callCount(), 0, "Scoped campaign 1 should not be called");
        assertEq(scopedCampaign2.callCount(), 0, "Scoped campaign 2 should not be called");
    }

    function test_scopedExecution_DifferentContexts() public {
        // Execute for newsletter context
        bytes memory newsletterInteraction = _createScopedInteraction(contextNewsletter, PressInteractions.OPEN_ARTICLE);
        bytes memory newsletterSignature = _signInteraction(newsletterInteraction);
        diamond.handleInteraction(newsletterInteraction, newsletterSignature);

        // Execute for creator context
        bytes memory creatorInteraction = _createScopedInteraction(contextCreator, PressInteractions.READ_ARTICLE);
        bytes memory creatorSignature = _signInteraction(creatorInteraction);
        diamond.handleInteraction(creatorInteraction, creatorSignature);

        // Verify correct campaigns were called
        assertEq(scopedCampaign1.callCount(), 1, "Newsletter campaign should be called once");
        assertEq(scopedCampaign2.callCount(), 1, "Creator campaign should be called once");
        assertEq(defaultCampaign1.callCount(), 0, "Default campaigns should not be called");
    }

    function test_scopedExecution_UnknownContext() public {
        // Create interaction with unknown context (no campaigns attached)
        bytes16 unknownContext = bytes16(uint128(999));
        bytes memory interaction = _createScopedInteraction(unknownContext, PressInteractions.OPEN_ARTICLE);
        bytes memory signature = _signInteraction(interaction);

        // Execute interaction - should not revert, just no campaigns called
        diamond.handleInteraction(interaction, signature);

        // Verify no campaigns were called (including defaults - they only execute for contextId == 0)
        assertEq(scopedCampaign1.callCount(), 0);
        assertEq(scopedCampaign2.callCount(), 0);
        assertEq(defaultCampaign1.callCount(), 0);
        assertEq(defaultCampaign2.callCount(), 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Helper functions                              */
    /* -------------------------------------------------------------------------- */

    function _createLegacyInteraction(InteractionType interactionType) internal view returns (bytes memory) {
        // Legacy format: [denominator][interactionType][user]
        bytes4 unwrappedType = InteractionType.unwrap(interactionType);
        return abi.encodePacked(DENOMINATOR_PRESS, unwrappedType, address(this));
    }

    function _createScopedInteraction(bytes16 contextId, InteractionType interactionType)
        internal
        view
        returns (bytes memory)
    {
        // Scoped format: [0xFF][contextId][denominator][interactionType][user]
        bytes4 unwrappedType = InteractionType.unwrap(interactionType);
        return abi.encodePacked(SCOPED_INTERACTION_MARKER, contextId, DENOMINATOR_PRESS, unwrappedType, address(this));
    }

    function _signInteraction(bytes memory interaction) internal view returns (bytes memory) {
        // Extract facet data based on format
        bytes memory facetData;

        if (interaction.length > 17 && uint8(interaction[0]) == SCOPED_INTERACTION_MARKER) {
            // Scoped: skip [0xFF][16 bytes contextId][1 byte denominator]
            facetData = new bytes(interaction.length - 18);
            for (uint256 i = 0; i < facetData.length; i++) {
                facetData[i] = interaction[i + 18];
            }
        } else {
            // Legacy: skip [1 byte denominator]
            facetData = new bytes(interaction.length - 1);
            for (uint256 i = 0; i < facetData.length; i++) {
                facetData[i] = interaction[i + 1];
            }
        }

        bytes32 domainSeparator = diamond.getDomainSeparator();

        // Build the digest
        bytes32 dataHash = keccak256(abi.encode(_VALIDATE_INTERACTION_TYPEHASH, productId, keccak256(facetData), address(this)));
        bytes32 fullHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, dataHash));

        // Sign the full hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(validatorPrivKey, fullHash);
        if (v != 27) {
            // then left-most bit of s has to be flipped to 1.
            s = s | bytes32(uint256(1) << 255);
        }

        // Compact the signature into a single bytes32
        return abi.encodePacked(r, s);
    }
}
