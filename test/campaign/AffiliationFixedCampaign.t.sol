// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EcosystemAwareTest} from "../EcosystemAwareTest.sol";
import "forge-std/Console.sol";
import {
    AffiliationFixedCampaign,
    AffiliationFixedCampaignConfig,
    FixedAffiliationTriggerConfig
} from "src/campaign/AffiliationFixedCampaign.sol";
import {CampaignBank} from "src/campaign/CampaignBank.sol";
import {InteractionCampaign} from "src/campaign/InteractionCampaign.sol";
import {CapConfig, CappedCampaign} from "src/campaign/libs/CappedCampaign.sol";
import {RewardChainingConfig} from "src/campaign/libs/RewardChainingCampaign.sol";
import {ActivationPeriod} from "src/campaign/libs/TimeLockedCampaign.sol";
import {InteractionTypeLib, ReferralInteractions} from "src/constants/InteractionType.sol";
import {
    PRODUCT_TYPE_DAPP,
    PRODUCT_TYPE_FEATURE_REFERRAL,
    PRODUCT_TYPE_PRESS,
    ProductTypes
} from "src/constants/ProductTypes.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";

/// @dev Test contract our fixed affiliation campaign
contract AffiliationFixedCampaignTest is EcosystemAwareTest {
    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");
    address private charlie = makeAddr("charlie");
    address private delta = makeAddr("delta");

    address private interactionEmitter;

    /// @dev The product interaction contract
    ProductInteractionDiamond private productInteraction;

    /// @dev The product id
    uint256 private productId;
    bytes32 private referralTree;

    /// @dev The bank we will use
    CampaignBank private campaignBank;

    /// @dev The campaign we will test
    AffiliationFixedCampaign private campaign;

    function setUp() public {
        _initEcosystemAwareTest();

        // Setup content with allowance for the operator
        (productId, productInteraction) = _mintProductWithInteraction(PRODUCT_TYPE_PRESS, "name", "press-domain");

        // Save the product interaction as the interaction emitter
        interactionEmitter = address(productInteraction);

        // Get the referral tree
        referralTree = productInteraction.getReferralTree();

        // Deploy the bank
        campaignBank = new CampaignBank(adminRegistry, productId, address(token));

        // Mint a few test tokens to the campaign
        token.mint(address(campaignBank), 1000 ether);

        // Start our bank
        vm.prank(productOwner);
        campaignBank.updateDistributionState(true);

        // Grant the right roles to the product interaction manager
        vm.prank(contractOwner);
        referralRegistry.grantAccessToTree(referralTree, contractOwner);

        // Fake the timestamp
        vm.warp(100);
    }

    function test_init() public pure {
        assertTrue(true);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Test construct                               */
    /* -------------------------------------------------------------------------- */

    function test_construct_InvalidConfig_emptyTrigger() public {
        AffiliationFixedCampaignConfig memory config = AffiliationFixedCampaignConfig({
            name: "test",
            triggers: new FixedAffiliationTriggerConfig[](0),
            capConfig: CapConfig({period: uint48(0), amount: uint208(0)}),
            activationPeriod: ActivationPeriod({start: uint48(0), end: uint48(0)}),
            campaignBank: campaignBank,
            chainingConfig: RewardChainingConfig({
                userPercent: 5000, // 50%
                deperditionPerLevel: 8000 // 80%
            })
        });

        vm.expectRevert(AffiliationFixedCampaign.InvalidConfig.selector);
        new AffiliationFixedCampaign(config, referralRegistry, adminRegistry, productInteraction);
    }

    function test_construct_InvalidConfig_noBank() public {
        AffiliationFixedCampaignConfig memory config = AffiliationFixedCampaignConfig({
            name: "test",
            triggers: _buildTriggers(),
            capConfig: CapConfig({period: uint48(0), amount: uint208(0)}),
            activationPeriod: ActivationPeriod({start: uint48(0), end: uint48(0)}),
            campaignBank: CampaignBank(address(0)),
            chainingConfig: RewardChainingConfig({
                userPercent: 5000, // 50%
                deperditionPerLevel: 8000 // 80%
            })
        });

        vm.expectRevert(AffiliationFixedCampaign.InvalidConfig.selector);
        new AffiliationFixedCampaign(config, referralRegistry, adminRegistry, productInteraction);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Test factory                                */
    /* -------------------------------------------------------------------------- */

    function test_factory() public {
        bytes4 identifier = bytes4(keccak256("frak.campaign.affiliation-fixed"));
        address deployed = campaignFactory.createCampaign(productInteraction, identifier, abi.encode(_simpleConfig()));

        (string memory campaignType,,) = AffiliationFixedCampaign(deployed).getMetadata();
        assertEq(campaignType, "frak.campaign.affiliation-fixed");
    }

    /* -------------------------------------------------------------------------- */
    /*                             Test metadata setup                            */
    /* -------------------------------------------------------------------------- */

    function test_metadata() public withSimpleConfig {
        // Ensure the metadata is correct
        (string memory campaignType, string memory version, bytes32 name) = campaign.getMetadata();

        assertEq(campaignType, "frak.campaign.affiliation-fixed");
        assertEq(version, "0.0.2");
        assertEq(name, bytes32("test"));
    }

    function test_getChainingConfig() public withSimpleConfig {
        // Ensure the chaining config is correct
        (,,, RewardChainingConfig memory chainingConfig) = campaign.getConfig();

        assertEq(chainingConfig.userPercent, 5000);
        assertEq(chainingConfig.deperditionPerLevel, 8000);
    }

    function test_supportProductType() public withSimpleConfig {
        assertEq(campaign.supportProductType(PRODUCT_TYPE_DAPP), false);
        assertEq(campaign.supportProductType(ProductTypes.wrap(uint256(1 << 9))), false);
        assertEq(campaign.supportProductType(PRODUCT_TYPE_PRESS), false);
        assertEq(campaign.supportProductType(PRODUCT_TYPE_FEATURE_REFERRAL), true);
        assertEq(
            campaign.supportProductType(PRODUCT_TYPE_FEATURE_REFERRAL | PRODUCT_TYPE_DAPP | PRODUCT_TYPE_PRESS), true
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                             Test running status                            */
    /* -------------------------------------------------------------------------- */

    function test_setRunningStatus() public withSimpleConfig {
        // Ensure the campaign is running
        assertTrue(campaign.isRunning());

        vm.prank(campaignManager);
        campaign.setRunningStatus(false);

        // Ensure the campaign is not running
        assertFalse(campaign.isRunning());

        // Ensure the product owner can start the campaign
        vm.prank(productOwner);
        campaign.setRunningStatus(true);

        // Ensure the campaign is running
        assertTrue(campaign.isRunning());
    }

    function test_setRunningStatus_Unauthorized() public withSimpleConfig {
        // Ensure the campaign is running
        assertTrue(campaign.isRunning());

        // Try to stop the campaign, ensure failing if we don't have the right roles
        vm.expectRevert(InteractionCampaign.Unauthorized.selector);
        campaign.setRunningStatus(false);

        // Try to stop the campaign, ensure failing if we don't have the right roles
        vm.prank(interactionManager);
        vm.expectRevert(InteractionCampaign.Unauthorized.selector);
        campaign.setRunningStatus(false);

        // Ensure the campaign is not running
        assertTrue(campaign.isRunning());
    }

    /* -------------------------------------------------------------------------- */
    /*                          Test campaign activation                          */
    /* -------------------------------------------------------------------------- */

    function test_setup_isActive() public withSimpleConfig {
        // Ensure the campaign is running
        assertTrue(campaign.isActive());
    }

    function test_isActive_interactionCampaignInactive() public withSimpleConfig {
        vm.prank(productOwner);
        campaign.setRunningStatus(false);

        // Ensure the campaign is running
        assertFalse(campaign.isActive());
    }

    function test_isActive_withActivationPeriod() public withActivationConfig(80, 120) {
        assertTrue(campaign.isActive());
    }

    function test_isActive_withActivationStartNotPassed() public withActivationConfig(80, 120) {
        vm.warp(75);
        assertFalse(campaign.isActive());
    }

    function test_isActive_withActivationEndPassed() public withActivationConfig(80, 120) {
        vm.warp(125);
        assertFalse(campaign.isActive());
    }

    function test_isActive_withBankDisabled() public withSimpleConfig {
        vm.prank(campaignManager);
        campaignBank.updateCampaignAuthorisation(address(campaign), false);

        assertFalse(campaign.isActive());
    }

    /* -------------------------------------------------------------------------- */
    /*                             Test config update                             */
    /* -------------------------------------------------------------------------- */

    function test_updateActivationPeriod_Unauthorized() public withSimpleConfig {
        vm.expectRevert(InteractionCampaign.Unauthorized.selector);
        campaign.updateActivationPeriod(ActivationPeriod(uint48(0), uint48(0)));
    }

    function test_updateCapConfig_Unauthorized() public withSimpleConfig {
        vm.expectRevert(InteractionCampaign.Unauthorized.selector);
        campaign.updateCapConfig(CapConfig(uint48(0), uint208(0)));
    }

    function test_updateActivationPeriod() public withSimpleConfig {
        assertTrue(campaign.isActive());

        uint48 time = uint48(block.timestamp);

        vm.prank(campaignManager);
        campaign.updateActivationPeriod(ActivationPeriod(time - 1, time + 1));
        assertTrue(campaign.isActive());

        // Get config
        (, ActivationPeriod memory config,,) = campaign.getConfig();
        assertEq(config.start, time - 1);
        assertEq(config.end, time + 1);

        vm.warp(time + 2);
        assertFalse(campaign.isActive());
    }

    function test_updateCapConfig() public withSimpleConfig {
        vm.prank(campaignManager);
        campaign.updateCapConfig(CapConfig(uint48(1312), uint208(10 ether)));

        // Get config
        (CapConfig memory config,,,) = campaign.getConfig();
        assertEq(config.period, uint48(1312));
        assertEq(config.amount, uint208(10 ether));
    }

    /* -------------------------------------------------------------------------- */
    /*                          Test interaction handling                         */
    /* -------------------------------------------------------------------------- */

    function test_handleInteraction_Unauthorized() public withSimpleConfig {
        bytes memory fckedUpData = hex"13";

        // Ensure only the emitter can push interactions
        vm.expectRevert(InteractionCampaign.Unauthorized.selector);
        campaign.handleInteraction(fckedUpData);
    }

    function test_handleInteraction_InactiveCampaign() public withSimpleConfig {
        bytes memory fckedUpData = hex"13";

        vm.prank(campaignManager);
        campaign.setRunningStatus(false);

        // Ensure only the emitter can push interactions
        vm.prank(interactionEmitter);
        vm.expectRevert(InteractionCampaign.InactiveCampaign.selector);
        campaign.handleInteraction(fckedUpData);
    }

    function test_handleInteraction_doNothingForUnknownInteraction() public withSimpleConfig {
        bytes memory fckedUpData = hex"13";

        vm.prank(interactionEmitter);
        campaign.handleInteraction(fckedUpData);

        // Ensure no reward was added
        assertNoRewardDistributed();
    }

    function test_handleInteraction_doNothingIfNoReferrer() public withSimpleConfig {
        bytes memory interactionData = InteractionTypeLib.packForCampaign(ReferralInteractions.REFERRED, alice);

        vm.prank(interactionEmitter);
        campaign.handleInteraction(interactionData);

        // Ensure no reward was added
        assertNoRewardDistributed();
    }

    function test_handleInteraction() public withSimpleConfig withReferralChain {
        bytes memory interactionData = InteractionTypeLib.packForCampaign(ReferralInteractions.REFERRED, alice);

        vm.prank(interactionEmitter);
        campaign.handleInteraction(interactionData);

        // Ensure the reward was added
        assertRewardDistributed();
    }

    /// @dev Test that the maxCount per user is effictive and taken in account
    /// @dev The simple config is set to have a maxCountPerUser of 1
    function test_handleInteraction_DontResitributeIfSpecified() public withSimpleConfig withReferralChain {
        bytes memory interactionData = InteractionTypeLib.packForCampaign(ReferralInteractions.REFERRED, alice);

        vm.prank(interactionEmitter);
        campaign.handleInteraction(interactionData);

        assertRewardDistributed();
        uint256 prevAliceBalance = campaignBank.getPendingAmount(alice);

        // Try to push the same interaction again
        vm.prank(interactionEmitter);
        campaign.handleInteraction(interactionData);

        // Ensure the reward was not added
        assertEq(campaignBank.getPendingAmount(alice), prevAliceBalance);
    }

    /// @dev Test that the maxCount per user is effictive and taken in account
    /// @dev The simple config is set to have a maxCountPerUser of 1
    function test_handleInteraction_InfiniteResitributeIfSpecified() public withSimpleConfig withReferralChain {
        bytes memory interactionData =
            InteractionTypeLib.packForCampaign(ReferralInteractions.REFERRAL_LINK_CREATION, alice);

        vm.prank(interactionEmitter);
        campaign.handleInteraction(interactionData);

        assertRewardDistributed();
        uint256 prevAliceBalance = campaignBank.getPendingAmount(alice);

        // Try to push the same interaction again
        vm.prank(interactionEmitter);
        campaign.handleInteraction(interactionData);

        // Ensure the reward was not added
        assertGt(campaignBank.getPendingAmount(alice), prevAliceBalance);
        prevAliceBalance = campaignBank.getPendingAmount(alice);

        // Try to push the same interaction again
        vm.prank(interactionEmitter);
        campaign.handleInteraction(interactionData);
        assertGt(campaignBank.getPendingAmount(alice), prevAliceBalance);
    }

    /// @dev Test that the maxCount per user is effictive and taken in account
    /// @dev The simple config is set to have a maxCountPerUser of 1
    function test_handleInteraction_DistributionCapHit() public withCappedConfig(20 ether, 10) withReferralChain {
        bytes memory interactionData =
            InteractionTypeLib.packForCampaign(ReferralInteractions.REFERRAL_LINK_CREATION, alice);

        // Distrubte two rewards (should hit the cap since simple config have reward of 10eth)
        vm.startPrank(interactionEmitter);
        campaign.handleInteraction(interactionData);
        campaign.handleInteraction(interactionData);
        vm.stopPrank();

        // Ensure the reward was added
        assertRewardDistributed();

        // Ensure next reward trigger the cap hit
        vm.prank(interactionEmitter);
        vm.expectRevert(CappedCampaign.DistributionCapReached.selector);
        campaign.handleInteraction(interactionData);
    }

    /// @dev Test that the maxCount per user is effictive and taken in account
    /// @dev The simple config is set to have a maxCountPerUser of 1
    function test_handleInteraction_DistributionCapReset() public withCappedConfig(20 ether, 10) withReferralChain {
        bytes memory interactionData =
            InteractionTypeLib.packForCampaign(ReferralInteractions.REFERRAL_LINK_CREATION, alice);

        // Distrubte two rewards (should hit the cap since simple config have reward of 10eth)
        vm.startPrank(interactionEmitter);
        campaign.handleInteraction(interactionData);
        campaign.handleInteraction(interactionData);
        vm.stopPrank();

        // Ensure the reward was added
        assertRewardDistributed();

        // Ensure next reward trigger the cap hit
        vm.prank(interactionEmitter);
        vm.expectRevert(CappedCampaign.DistributionCapReached.selector);
        campaign.handleInteraction(interactionData);

        uint256 prevAliceBalance = campaignBank.getPendingAmount(alice);

        // Ensure that if we move 11seconds seconds forward, the cap is reset
        uint48 prevTimestamp = uint48(block.timestamp);
        vm.warp(block.timestamp + 11);

        vm.expectEmit(true, true, true, true);
        emit CappedCampaign.DistributionCapReset(uint48(prevTimestamp), 20 ether);
        vm.prank(interactionEmitter);
        campaign.handleInteraction(interactionData);

        // Ensure the reward was added
        assertGt(campaignBank.getPendingAmount(alice), prevAliceBalance);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Assertion helpers                             */
    /* -------------------------------------------------------------------------- */

    function assertNoRewardDistributed() private view {
        assertEq(campaignBank.getPendingAmount(alice), 0);
        assertEq(campaignBank.getPendingAmount(bob), 0);
        assertEq(campaignBank.getPendingAmount(charlie), 0);
        assertEq(campaignBank.getPendingAmount(delta), 0);
    }

    function assertRewardDistributed() private view {
        assertGt(campaignBank.getPendingAmount(alice), 0);
        assertGt(campaignBank.getPendingAmount(bob), 0);
        assertGt(campaignBank.getPendingAmount(charlie), 0);
        assertGt(campaignBank.getPendingAmount(delta), 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                                State helpers                               */
    /* -------------------------------------------------------------------------- */

    function _simpleConfig() private view returns (AffiliationFixedCampaignConfig memory) {
        return AffiliationFixedCampaignConfig({
            name: "test",
            triggers: _buildTriggers(),
            capConfig: CapConfig({period: uint48(0), amount: uint208(0)}),
            activationPeriod: ActivationPeriod({start: uint48(0), end: uint48(0)}),
            campaignBank: campaignBank,
            chainingConfig: RewardChainingConfig({
                userPercent: 5000, // 50%
                deperditionPerLevel: 8000 // 80%
            })
        });
    }

    modifier withSimpleConfig() {
        vm.pauseGasMetering();
        // Build a config
        AffiliationFixedCampaignConfig memory config = _simpleConfig();

        // Continue the execution
        _campaignSetup(config);
        vm.resumeGasMetering();
        _;
    }

    modifier withCappedConfig(uint256 capAmount, uint256 capPeriod) {
        vm.pauseGasMetering();
        // Build a config
        AffiliationFixedCampaignConfig memory config = AffiliationFixedCampaignConfig({
            name: "test",
            triggers: _buildTriggers(),
            capConfig: CapConfig({period: uint48(capPeriod), amount: uint208(capAmount)}),
            activationPeriod: ActivationPeriod({start: uint48(0), end: uint48(0)}),
            campaignBank: campaignBank,
            chainingConfig: RewardChainingConfig({
                userPercent: 5000, // 50%
                deperditionPerLevel: 8000 // 80%
            })
        });

        // Continue the execution
        _campaignSetup(config);
        vm.resumeGasMetering();
        _;
    }

    modifier withActivationConfig(uint256 start, uint256 end) {
        vm.pauseGasMetering();
        // Build a config
        AffiliationFixedCampaignConfig memory config = AffiliationFixedCampaignConfig({
            name: "test",
            triggers: _buildTriggers(),
            capConfig: CapConfig({period: uint48(0), amount: uint208(0)}),
            activationPeriod: ActivationPeriod({start: uint48(start), end: uint48(end)}),
            campaignBank: campaignBank,
            chainingConfig: RewardChainingConfig({
                userPercent: 5000, // 50%
                deperditionPerLevel: 8000 // 80%
            })
        });

        // Continue the execution
        _campaignSetup(config);
        vm.resumeGasMetering();
        _;
    }

    function _buildTriggers() private pure returns (FixedAffiliationTriggerConfig[] memory triggers) {
        triggers = new FixedAffiliationTriggerConfig[](2);

        triggers[0] = FixedAffiliationTriggerConfig({
            interactionType: ReferralInteractions.REFERRED,
            baseReward: 10 ether,
            maxCountPerUser: 1
        });
        triggers[1] = FixedAffiliationTriggerConfig({
            interactionType: ReferralInteractions.REFERRAL_LINK_CREATION,
            baseReward: 10 ether,
            maxCountPerUser: 0
        });
    }

    function _campaignSetup(AffiliationFixedCampaignConfig memory _config) private {
        // Deploy the campaign
        campaign = new AffiliationFixedCampaign(_config, referralRegistry, adminRegistry, productInteraction);

        // Allow the campaign bank to distribute rewards
        vm.prank(campaignManager);
        campaignBank.updateCampaignAuthorisation(address(campaign), true);
    }

    modifier withReferralChain() {
        vm.startPrank(contractOwner);
        referralRegistry.saveReferrer(referralTree, alice, bob);
        referralRegistry.saveReferrer(referralTree, bob, charlie);
        referralRegistry.saveReferrer(referralTree, charlie, delta);
        vm.stopPrank();
        _;
    }
}
