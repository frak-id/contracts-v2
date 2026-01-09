// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {RewarderHub, RewardOp} from "src/reward/RewarderHub.sol";
import {REWARDER_ROLE, RESOLVER_ROLE, UPGRADE_ROLE} from "src/constants/Roles.sol";
import {MockErc20} from "../utils/MockErc20.sol";
import {LibClone} from "solady/utils/LibClone.sol";

/// @title RewarderHubBaseTest
/// @notice Base test contract with shared setup for RewarderHub tests
abstract contract RewarderHubBaseTest is Test {
    using LibClone for address;

    RewarderHub public hub;
    MockErc20 public token;
    MockErc20 public token2;

    address public owner = makeAddr("owner");
    address public rewarder = makeAddr("rewarder");
    address public resolver = makeAddr("resolver");
    address public bank = makeAddr("bank");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    bytes32 public userId1 = keccak256("userId1");
    bytes32 public userId2 = keccak256("userId2");

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
        hub.grantRoles(resolver, RESOLVER_ROLE);
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

    function _lockReward(bytes32 userId, uint256 amount) internal {
        vm.prank(rewarder);
        hub.lockReward(userId, amount, address(token), bank, attestation);
    }

    function _resolveUserId(bytes32 userId, address wallet) internal {
        vm.prank(resolver);
        hub.resolveUserId(userId, wallet);
    }

    function _createRewardOp(bool isLock, bytes32 target, uint256 amount, address _token, address _bank)
        internal
        view
        returns (RewardOp memory)
    {
        return RewardOp({
            isLock: isLock,
            target: target,
            amount: amount,
            token: _token,
            bank: _bank,
            attestation: attestation
        });
    }

    function _addressToBytes32(address addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }
}
