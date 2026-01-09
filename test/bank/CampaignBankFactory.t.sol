// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {CampaignBankFactory} from "src/bank/CampaignBankFactory.sol";
import {CampaignBank, CAMPAIGN_BANK_MANAGER_ROLE} from "src/bank/CampaignBank.sol";

/// @title CampaignBankFactoryTest
/// @notice Comprehensive tests for CampaignBankFactory contract
contract CampaignBankFactoryTest is Test {
    CampaignBankFactory public factory;

    address public rewarderHub = makeAddr("rewarderHub");
    address public merchant1 = makeAddr("merchant1");
    address public merchant2 = makeAddr("merchant2");

    function setUp() public {
        factory = new CampaignBankFactory(rewarderHub);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Constructor                                   */
    /* -------------------------------------------------------------------------- */

    function test_constructor_setsRewarderHub() public view {
        assertEq(factory.REWARDER_HUB(), rewarderHub);
    }

    function test_constructor_setsImplementation() public view {
        assertTrue(factory.IMPLEMENTATION() != address(0));
    }

    function test_constructor_revert_invalidRewarderHub() public {
        vm.expectRevert(CampaignBankFactory.InvalidRewarderHub.selector);
        new CampaignBankFactory(address(0));
    }

    function test_deployBank_revert_invalidOwner() public {
        vm.expectRevert(CampaignBankFactory.InvalidOwner.selector);
        factory.deployBank(address(0));
    }

    function test_deployBank_withSalt_revert_invalidOwner() public {
        vm.expectRevert(CampaignBankFactory.InvalidOwner.selector);
        factory.deployBank(address(0), keccak256("salt"));
    }

    /* -------------------------------------------------------------------------- */
    /*                              deployBank                                    */
    /* -------------------------------------------------------------------------- */

    function test_deployBank_success() public {
        vm.expectEmit(true, false, false, false);
        emit CampaignBankFactory.BankDeployed(merchant1, address(0)); // We don't know the address yet

        CampaignBank bank = factory.deployBank(merchant1);

        assertTrue(address(bank) != address(0));
        assertEq(bank.owner(), merchant1);
        assertEq(bank.REWARDER_HUB(), rewarderHub);
        assertTrue(bank.hasAnyRole(merchant1, CAMPAIGN_BANK_MANAGER_ROLE));
    }

    function test_deployBank_multipleMerchants() public {
        CampaignBank bank1 = factory.deployBank(merchant1);
        CampaignBank bank2 = factory.deployBank(merchant2);

        assertTrue(address(bank1) != address(bank2));
        assertEq(bank1.owner(), merchant1);
        assertEq(bank2.owner(), merchant2);
    }

    function test_deployBank_sameMerchantMultipleBanks() public {
        CampaignBank bank1 = factory.deployBank(merchant1);
        CampaignBank bank2 = factory.deployBank(merchant1);

        // Same merchant can have multiple banks
        assertTrue(address(bank1) != address(bank2));
        assertEq(bank1.owner(), merchant1);
        assertEq(bank2.owner(), merchant1);
    }

    /* -------------------------------------------------------------------------- */
    /*                          deployBank with salt                              */
    /* -------------------------------------------------------------------------- */

    function test_deployBank_withSalt_success() public {
        bytes32 salt = keccak256("salt1");

        CampaignBank bank = factory.deployBank(merchant1, salt);

        assertTrue(address(bank) != address(0));
        assertEq(bank.owner(), merchant1);
        assertEq(bank.REWARDER_HUB(), rewarderHub);
    }

    function test_deployBank_withSalt_deterministicAddress() public {
        bytes32 salt = keccak256("salt1");

        address predicted = factory.predictBankAddress(salt);
        CampaignBank bank = factory.deployBank(merchant1, salt);

        assertEq(address(bank), predicted);
    }

    function test_deployBank_withSalt_differentSalts() public {
        bytes32 salt1 = keccak256("salt1");
        bytes32 salt2 = keccak256("salt2");

        CampaignBank bank1 = factory.deployBank(merchant1, salt1);
        CampaignBank bank2 = factory.deployBank(merchant1, salt2);

        assertTrue(address(bank1) != address(bank2));
    }

    function test_deployBank_withSalt_revert_sameSalt() public {
        bytes32 salt = keccak256("salt1");

        factory.deployBank(merchant1, salt);

        // Same owner + same salt should fail
        vm.expectRevert();
        factory.deployBank(merchant1, salt);
    }

    function test_deployBank_withSalt_sameSaltDifferentOwner_reverts() public {
        bytes32 salt = keccak256("salt1");

        // First deployment succeeds
        factory.deployBank(merchant1, salt);

        // Same salt with different owner should fail (clone address is salt-based only)
        vm.expectRevert();
        factory.deployBank(merchant2, salt);
    }

    /* -------------------------------------------------------------------------- */
    /*                          predictBankAddress                                */
    /* -------------------------------------------------------------------------- */

    function test_predictBankAddress_accuracy() public {
        bytes32 salt = keccak256("predictTest");

        address predicted = factory.predictBankAddress(salt);
        CampaignBank actual = factory.deployBank(merchant1, salt);

        assertEq(predicted, address(actual));
    }

    function test_predictBankAddress_differentSalts() public {
        bytes32 salt1 = keccak256("salt1");
        bytes32 salt2 = keccak256("salt2");

        address predicted1 = factory.predictBankAddress(salt1);
        address predicted2 = factory.predictBankAddress(salt2);

        assertTrue(predicted1 != predicted2);
    }

    function test_predictBankAddress_sameSaltSameAddress() public {
        bytes32 salt = keccak256("sameSalt");

        // With clones, predicted address depends only on salt
        address predicted = factory.predictBankAddress(salt);

        // Deploy with merchant1
        CampaignBank bank = factory.deployBank(merchant1, salt);
        assertEq(address(bank), predicted);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Events                                        */
    /* -------------------------------------------------------------------------- */

    function test_deployBank_emitsBankDeployed() public {
        // Get predicted address first
        bytes32 salt = keccak256("eventTest");
        address predicted = factory.predictBankAddress(salt);

        vm.expectEmit(true, true, false, false);
        emit CampaignBankFactory.BankDeployed(merchant1, predicted);

        factory.deployBank(merchant1, salt);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Fuzz Tests                                    */
    /* -------------------------------------------------------------------------- */

    function testFuzz_deployBank_anyOwner(address _owner) public {
        vm.assume(_owner != address(0));

        CampaignBank bank = factory.deployBank(_owner);

        assertEq(bank.owner(), _owner);
        assertEq(bank.REWARDER_HUB(), rewarderHub);
    }

    function testFuzz_deployBank_anySalt(bytes32 _salt) public {
        CampaignBank bank = factory.deployBank(merchant1, _salt);

        assertEq(bank.owner(), merchant1);

        // Verify prediction works
        // Note: Can't predict after deployment, so we check the bank properties
        assertEq(bank.REWARDER_HUB(), rewarderHub);
    }

    function testFuzz_predictBankAddress_consistency(bytes32 _salt) public {
        // Predict twice should give same result
        address predicted1 = factory.predictBankAddress(_salt);
        address predicted2 = factory.predictBankAddress(_salt);

        assertEq(predicted1, predicted2);
    }

    function testFuzz_predictAndDeploy_match(address _owner, bytes32 _salt) public {
        vm.assume(_owner != address(0));

        address predicted = factory.predictBankAddress(_salt);
        CampaignBank actual = factory.deployBank(_owner, _salt);

        assertEq(predicted, address(actual));
    }
}
