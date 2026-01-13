// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockErc20} from "../utils/MockErc20.sol";
import {Test} from "forge-std/Test.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {REWARDER_ROLE} from "src/constants/Roles.sol";
import {RewardOp, RewarderHub} from "src/reward/RewarderHub.sol";

/// @title RewarderHubBaseTest
/// @notice Base test contract with shared setup for RewarderHub tests
abstract contract RewarderHubBaseTest is Test {
    using LibClone for address;

    RewarderHub public hub;
    MockErc20 public token;
    MockErc20 public token2;

    address public owner = makeAddr("owner");
    address public rewarder = makeAddr("rewarder");
    address public bank = makeAddr("bank");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    bytes public attestation = "test-attestation";

    function setUp() public virtual {
        // Deploy hub implementation and proxy
        RewarderHub implementation = new RewarderHub();
        hub = RewarderHub(address(implementation).clone());
        hub.init(owner);

        // Deploy mock tokens
        token = new MockErc20();
        token2 = new MockErc20();

        // Setup roles
        vm.startPrank(owner);
        hub.grantRoles(rewarder, REWARDER_ROLE);
        vm.stopPrank();

        // Fund bank with tokens
        token.mint(bank, 1_000_000e18);
        token2.mint(bank, 1_000_000e18);

        // Bank approves hub
        vm.startPrank(bank);
        token.approve(address(hub), type(uint256).max);
        token2.approve(address(hub), type(uint256).max);
        vm.stopPrank();
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Helpers                                  */
    /* -------------------------------------------------------------------------- */

    function _pushReward(address wallet, uint256 amount) internal {
        vm.prank(rewarder);
        hub.pushReward(wallet, amount, address(token), bank, attestation);
    }

    function _createRewardOp(address wallet, uint256 amount, address _token, address _bank)
        internal
        view
        returns (RewardOp memory)
    {
        return RewardOp({wallet: wallet, amount: amount, token: _token, bank: _bank, attestation: attestation});
    }
}
