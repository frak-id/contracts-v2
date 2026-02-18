// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockErc20} from "../utils/MockErc20.sol";
import {Test} from "forge-std/Test.sol";
import {COMPLIANCE_ROLE, REWARDER_ROLE, UPGRADE_ROLE} from "src/constants/Roles.sol";
import {CAMPAIGN_BANK_MANAGER_ROLE, CampaignBank} from "src/bank/CampaignBank.sol";
import {CampaignBankFactory} from "src/bank/CampaignBankFactory.sol";
import {FrozenFundsRecoverOp, RewardOp, RewarderHub} from "src/reward/RewarderHub.sol";
import {ERC1967Proxy} from
    "lib/FreshCryptoLib/solidity/tests/WebAuthn_forge/lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title RewarderHubIntegrationTest
/// @notice Full integration tests across factory, bank, hub and claims
contract RewarderHubIntegrationTest is Test {
    RewarderHub public hub;
    CampaignBankFactory public factory;

    address public owner = makeAddr("owner");
    address public rewarder = makeAddr("rewarder");
    address public compliance = makeAddr("compliance");

    bytes public attestation = "integration-attestation";

    function setUp() public {
        // Deploy hub via ERC1967 proxy
        RewarderHub implementation = new RewarderHub();
        bytes memory initData = abi.encodeCall(RewarderHub.init, (owner));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        hub = RewarderHub(address(proxy));

        vm.startPrank(owner);
        hub.grantRoles(rewarder, REWARDER_ROLE);
        hub.grantRoles(compliance, COMPLIANCE_ROLE);
        vm.stopPrank();

        factory = new CampaignBankFactory(address(hub));
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Helpers                                  */
    /* -------------------------------------------------------------------------- */

    function _deployFundOpenBank(address _merchant, MockErc20 _token, uint256 _amount)
        internal
        returns (CampaignBank bank)
    {
        bank = factory.deployBank(_merchant);

        _token.mint(_merchant, _amount);

        vm.startPrank(_merchant);
        _token.approve(address(bank), _amount);
        bank.deposit(address(_token), _amount);
        bank.setOpen(true);
        bank.updateAllowance(address(_token), _amount);
        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*                                Full Flows                                  */
    /* -------------------------------------------------------------------------- */

    function test_fullFlow_deployBankDepositPushClaim() public {
        address merchant = makeAddr("merchant");
        address user = makeAddr("user");
        MockErc20 token = new MockErc20();

        CampaignBank bank = _deployFundOpenBank(merchant, token, 10_000e18);

        vm.prank(rewarder);
        hub.pushReward(user, 1_000e18, address(token), address(bank), attestation);

        vm.prank(user);
        uint256 claimed = hub.claim(address(token));

        assertEq(claimed, 1_000e18);
        assertEq(token.balanceOf(user), 1_000e18);
        assertEq(token.balanceOf(address(bank)), 9_000e18);
        assertEq(hub.getPendingBalance(address(token)), 0);
        assertEq(hub.getClaimable(user, address(token)), 0);
    }

    function test_fullFlow_batchRewardsMultipleUsers() public {
        address merchant = makeAddr("merchant");
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        address user3 = makeAddr("user3");
        MockErc20 token = new MockErc20();

        CampaignBank bank = _deployFundOpenBank(merchant, token, 10_000e18);

        RewardOp[] memory ops = new RewardOp[](3);
        ops[0] = RewardOp({
            wallet: user1,
            amount: 100e18,
            token: address(token),
            bank: address(bank),
            attestation: attestation
        });
        ops[1] = RewardOp({
            wallet: user2,
            amount: 200e18,
            token: address(token),
            bank: address(bank),
            attestation: attestation
        });
        ops[2] = RewardOp({
            wallet: user3,
            amount: 300e18,
            token: address(token),
            bank: address(bank),
            attestation: attestation
        });

        vm.prank(rewarder);
        hub.batch(ops);

        vm.prank(user1);
        hub.claim(address(token));
        vm.prank(user2);
        hub.claim(address(token));
        vm.prank(user3);
        hub.claim(address(token));

        assertEq(token.balanceOf(user1), 100e18);
        assertEq(token.balanceOf(user2), 200e18);
        assertEq(token.balanceOf(user3), 300e18);
        assertEq(token.balanceOf(address(bank)), 9_400e18);
        assertEq(hub.getPendingBalance(address(token)), 0);
    }

    function test_fullFlow_freezeAndRecover() public {
        address merchant = makeAddr("merchant");
        address user = makeAddr("user");
        address recipient = makeAddr("recipient");
        MockErc20 token = new MockErc20();

        CampaignBank bank = _deployFundOpenBank(merchant, token, 10_000e18);

        vm.prank(rewarder);
        hub.pushReward(user, 500e18, address(token), address(bank), attestation);

        vm.prank(compliance);
        hub.freezeUser(user);

        vm.warp(block.timestamp + hub.FREEZE_DURATION() + 1);

        FrozenFundsRecoverOp[] memory ops = new FrozenFundsRecoverOp[](1);
        ops[0] = FrozenFundsRecoverOp({wallet: user, token: address(token)});

        vm.prank(compliance);
        hub.recoverFrozenFunds(ops, recipient);

        assertEq(token.balanceOf(recipient), 500e18);
        assertEq(hub.getClaimable(user, address(token)), 0);
        assertEq(hub.getPendingBalance(address(token)), 0);
    }

    function test_fullFlow_closeBankWithdrawRemaining() public {
        address merchant = makeAddr("merchant");
        address user = makeAddr("user");
        MockErc20 token = new MockErc20();

        CampaignBank bank = _deployFundOpenBank(merchant, token, 10_000e18);

        vm.prank(rewarder);
        hub.pushReward(user, 1_000e18, address(token), address(bank), attestation);

        vm.startPrank(merchant);
        bank.setOpen(false);
        bank.withdraw(address(token), 9_000e18, merchant);
        vm.stopPrank();

        assertEq(token.balanceOf(merchant), 9_000e18);
        assertEq(hub.getClaimable(user, address(token)), 1_000e18);
        assertEq(hub.getPendingBalance(address(token)), 1_000e18);

        vm.prank(user);
        hub.claim(address(token));
        assertEq(token.balanceOf(user), 1_000e18);
    }

    function test_fullFlow_multipleBanksMultipleTokens() public {
        address merchant1 = makeAddr("merchant1");
        address merchant2 = makeAddr("merchant2");
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        MockErc20 token1 = new MockErc20();
        MockErc20 token2 = new MockErc20();

        CampaignBank bank1 = _deployFundOpenBank(merchant1, token1, 10_000e18);
        CampaignBank bank2 = _deployFundOpenBank(merchant2, token2, 20_000e18);

        RewardOp[] memory ops = new RewardOp[](3);
        ops[0] = RewardOp({
            wallet: user1,
            amount: 120e18,
            token: address(token1),
            bank: address(bank1),
            attestation: attestation
        });
        ops[1] = RewardOp({
            wallet: user2,
            amount: 80e18,
            token: address(token1),
            bank: address(bank1),
            attestation: attestation
        });
        ops[2] = RewardOp({
            wallet: user1,
            amount: 500e18,
            token: address(token2),
            bank: address(bank2),
            attestation: attestation
        });

        vm.prank(rewarder);
        hub.batch(ops);

        vm.startPrank(user1);
        hub.claim(address(token1));
        hub.claim(address(token2));
        vm.stopPrank();

        vm.prank(user2);
        hub.claim(address(token1));

        assertEq(token1.balanceOf(user1), 120e18);
        assertEq(token1.balanceOf(user2), 80e18);
        assertEq(token2.balanceOf(user1), 500e18);

        assertEq(hub.getPendingBalance(address(token1)), 0);
        assertEq(hub.getPendingBalance(address(token2)), 0);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Proxy Safety                                */
    /* -------------------------------------------------------------------------- */

    function test_proxyDeployment_uninitializedImplementation() public {
        RewarderHub implementation = new RewarderHub();

        vm.expectRevert();
        implementation.init(owner);
    }

    function test_proxyDeployment_cannotReinitialize() public {
        vm.expectRevert();
        hub.init(owner);
    }
}
