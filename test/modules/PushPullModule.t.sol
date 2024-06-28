// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockErc20} from "../utils/MockErc20.sol";
import {Test} from "forge-std/Test.sol";
import {PushPullModule} from "src/modules/PushPullModule.sol";

contract PushPullModuleTest is Test {
    /// @dev The module we will test
    MockPushPull private pushPullModule;

    /// @dev A few mock erc20 tokens
    MockErc20 private token = new MockErc20();

    /// @dev a few test users
    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");

    function setUp() public {
        pushPullModule = new MockPushPull(address(token));
    }

    /// @dev Test the addReward method, ensure it's failing if it hasn't enough token
    function test_addReward_NotEnoughToken() public {
        // Add some token to the user
        token.mint(address(pushPullModule), 100);

        // Try to add more than we have
        vm.expectRevert(PushPullModule.NotEnoughToken.selector);
        pushPullModule.addReward(alice, 101);
    }

    /// @dev Test the addReward method, ensure it's failing if it hasn't enough token
    function test_fuzz_addReward_NotEnoughToken(uint256 amount) public {
        vm.assume(amount < 5_000_000 ether);

        // Add some token to the user
        token.mint(address(pushPullModule), amount);

        // Try to add more than we have
        vm.expectRevert(PushPullModule.NotEnoughToken.selector);
        pushPullModule.addReward(alice, amount + 1);
    }

    function test_addReward() public {
        token.mint(address(pushPullModule), 100 ether);

        pushPullModule.addReward(alice, 50 ether);
        pushPullModule.addReward(bob, 50 ether);

        assertEq(50 ether, pushPullModule.getPendingAmount(alice));
        assertEq(50 ether, pushPullModule.getPendingAmount(bob));
        assertEq(100 ether, pushPullModule.getTotalPending());
    }

    function test_addRewards() public {
        token.mint(address(pushPullModule), 100 ether);

        PushPullModule.Reward[] memory rewards = new PushPullModule.Reward[](2);

        rewards[0] = PushPullModule.Reward(alice, 50 ether);
        rewards[1] = PushPullModule.Reward(bob, 50 ether);

        pushPullModule.addRewards(rewards);

        assertEq(50 ether, pushPullModule.getPendingAmount(alice));
        assertEq(50 ether, pushPullModule.getPendingAmount(bob));
        assertEq(100 ether, pushPullModule.getTotalPending());
    }

    function test_addRewards_NotEnoughToken() public {
        token.mint(address(pushPullModule), 100 ether);

        PushPullModule.Reward[] memory rewards = new PushPullModule.Reward[](2);

        rewards[0] = PushPullModule.Reward(alice, 50 ether);
        rewards[1] = PushPullModule.Reward(bob, 51 ether);

        vm.expectRevert(PushPullModule.NotEnoughToken.selector);
        pushPullModule.addRewards(rewards);
    }

    function test_fuzz_addReward(address user, uint256 amount) public {
        vm.assume(amount < 5_000_000 ether);
        token.mint(address(pushPullModule), amount);

        pushPullModule.addReward(user, amount);

        assertEq(amount, pushPullModule.getPendingAmount(user));
    }

    function test_claim_single() public {
        token.mint(address(pushPullModule), 100 ether);

        pushPullModule.addReward(alice, 50 ether);
        pushPullModule.addReward(bob, 50 ether);

        pushPullModule.pullReward(alice);

        assertEq(0, pushPullModule.getPendingAmount(alice));
        assertEq(50 ether, token.balanceOf(alice));
        assertEq(50 ether, pushPullModule.getPendingAmount(bob));

        pushPullModule.pullReward(bob);
        assertEq(0, pushPullModule.getPendingAmount(bob));
        assertEq(50 ether, token.balanceOf(bob));

        assertEq(0, pushPullModule.getTotalPending());

        // Ensure a re claimn doesn't change the balance
        pushPullModule.pullReward(alice);
        assertEq(0, pushPullModule.getPendingAmount(alice));
        assertEq(50 ether, token.balanceOf(alice));
    }

    function tes_fuzz_claim_single(address user, uint256 amount) public {
        vm.assume(amount < 5_000_000 ether);
        token.mint(address(pushPullModule), amount);

        pushPullModule.addReward(user, amount);

        pushPullModule.pullReward(user);

        assertEq(0, pushPullModule.getPendingAmount(user));
        assertEq(amount, token.balanceOf(user));
    }
}

contract MockPushPull is PushPullModule {
    constructor(address token) PushPullModule(token) {}

    function addReward(address user, uint256 amount) public {
        _pushReward(user, amount);
    }

    function addRewards(Reward[] memory rewards) public {
        _pushRewards(rewards);
    }
}
