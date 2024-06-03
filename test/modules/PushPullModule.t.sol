// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MockErc20} from "../utils/MockErc20.sol";
import {Test} from "forge-std/Test.sol";
import {PushPullModule} from "src/modules/PushPullModule.sol";

contract PushPullModuleTest is Test {
    /// @dev The module we will test
    MockPushPull private pushPullModule;

    /// @dev A few mock erc20 tokens
    MockErc20 private token1 = new MockErc20();
    MockErc20 private token2 = new MockErc20();
    MockErc20 private token3 = new MockErc20();

    /// @dev a few test users
    address private alice = makeAddr("alice");
    address private bob = makeAddr("bob");

    function setUp() public {
        pushPullModule = new MockPushPull();
    }

    /// @dev Test the addReward method, ensure it's failing if it hasn't enough token
    function test_addReward_NotEnoughToken() public {
        // Add some token to the user
        token1.mint(address(pushPullModule), 100);

        // Try to add more than we have
        vm.expectRevert(PushPullModule.NotEnoughToken.selector);
        pushPullModule.addReward(alice, address(token1), 101);

        // Try to add more than we have
        vm.expectRevert(PushPullModule.NotEnoughToken.selector);
        pushPullModule.addReward(alice, address(token2), 1);

        // Try to add more than we have
        vm.expectRevert(PushPullModule.NotEnoughToken.selector);
        pushPullModule.addReward(bob, address(token3), 1);
    }

    /// @dev Test the addReward method, ensure it's failing if it hasn't enough token
    function test_fuzz_addReward_NotEnoughToken(uint256 amount) public {
        vm.assume(amount < 5_000_000 ether);

        // Add some token to the user
        token1.mint(address(pushPullModule), amount);

        // Try to add more than we have
        vm.expectRevert(PushPullModule.NotEnoughToken.selector);
        pushPullModule.addReward(alice, address(token1), amount + 1);
    }

    function test_addReward() public {
        token1.mint(address(pushPullModule), 100 ether);

        pushPullModule.addReward(alice, address(token1), 50 ether);
        pushPullModule.addReward(bob, address(token1), 50 ether);

        assertEq(50 ether, pushPullModule.getPendingAmount(alice, address(token1)));
        assertEq(50 ether, pushPullModule.getPendingAmount(bob, address(token1)));
        assertEq(100 ether, pushPullModule.getTotalPending(address(token1)));

        token2.mint(address(pushPullModule), 1);
        pushPullModule.addReward(alice, address(token2), 1);
        assertEq(1, pushPullModule.getPendingAmount(alice, address(token2)));
        assertEq(1, pushPullModule.getTotalPending(address(token2)));
    }

    function test_fuzz_addReward(address user, uint256 amount) public {
        vm.assume(amount < 5_000_000 ether);
        token1.mint(address(pushPullModule), amount);

        pushPullModule.addReward(user, address(token1), amount);

        assertEq(amount, pushPullModule.getPendingAmount(user, address(token1)));
    }

    function test_claim_single() public {
        token1.mint(address(pushPullModule), 100 ether);

        pushPullModule.addReward(alice, address(token1), 50 ether);
        pushPullModule.addReward(bob, address(token1), 50 ether);

        vm.prank(alice);
        pushPullModule.pullReward(address(token1));

        assertEq(0, pushPullModule.getPendingAmount(alice, address(token1)));
        assertEq(50 ether, token1.balanceOf(alice));
        assertEq(50 ether, pushPullModule.getPendingAmount(bob, address(token1)));

        pushPullModule.pullReward(bob, address(token1));
        assertEq(0, pushPullModule.getPendingAmount(bob, address(token1)));
        assertEq(50 ether, token1.balanceOf(bob));

        assertEq(0, pushPullModule.getTotalPending(address(token1)));

        // Ensure a re claimn doesn't change the balance
        pushPullModule.pullReward(alice, address(token1));
        assertEq(0, pushPullModule.getPendingAmount(alice, address(token1)));
        assertEq(50 ether, token1.balanceOf(alice));
    }

    function tes_fuzz_claim_single(address user, uint256 amount) public {
        vm.assume(amount < 5_000_000 ether);
        token1.mint(address(pushPullModule), amount);

        pushPullModule.addReward(user, address(token1), amount);

        if (amount % 2 == 0) {
            vm.prank(user);
            pushPullModule.pullReward(address(token1));
        } else {
            pushPullModule.pullReward(user, address(token1));
        }

        assertEq(0, pushPullModule.getPendingAmount(user, address(token1)));
        assertEq(amount, token1.balanceOf(user));
    }

    function test_claim_multi() public {
        token1.mint(address(pushPullModule), 100 ether);
        token2.mint(address(pushPullModule), 100 ether);
        token3.mint(address(pushPullModule), 100 ether);

        pushPullModule.addReward(alice, address(token1), 50 ether);
        pushPullModule.addReward(alice, address(token2), 50 ether);
        pushPullModule.addReward(alice, address(token3), 50 ether);
        pushPullModule.addReward(bob, address(token1), 50 ether);
        pushPullModule.addReward(bob, address(token2), 50 ether);
        pushPullModule.addReward(bob, address(token3), 50 ether);

        address[] memory tokens = new address[](3);
        tokens[0] = address(token1);
        tokens[1] = address(token2);
        tokens[2] = address(token3);

        vm.prank(alice);
        pushPullModule.pullRewards(tokens);

        assertEq(0, pushPullModule.getPendingAmount(alice, address(token1)));
        assertEq(0, pushPullModule.getPendingAmount(alice, address(token2)));
        assertEq(0, pushPullModule.getPendingAmount(alice, address(token3)));
        assertEq(50 ether, token1.balanceOf(alice));
        assertEq(50 ether, token2.balanceOf(alice));
        assertEq(50 ether, token3.balanceOf(alice));

        pushPullModule.pullRewards(bob, tokens);
        assertEq(0, pushPullModule.getPendingAmount(bob, address(token1)));
        assertEq(0, pushPullModule.getPendingAmount(bob, address(token2)));
        assertEq(0, pushPullModule.getPendingAmount(bob, address(token3)));
        assertEq(50 ether, token1.balanceOf(bob));
        assertEq(50 ether, token2.balanceOf(bob));
        assertEq(50 ether, token3.balanceOf(bob));

        assertEq(0, pushPullModule.getTotalPending(address(token1)));
        assertEq(0, pushPullModule.getTotalPending(address(token2)));
        assertEq(0, pushPullModule.getTotalPending(address(token3)));
    }

    function test_fuzz_claim_multi(address user, uint256 amount) public {
        vm.assume(amount < 5_000_000 ether);
        token1.mint(address(pushPullModule), amount);
        token2.mint(address(pushPullModule), amount);
        token3.mint(address(pushPullModule), amount);

        pushPullModule.addReward(user, address(token1), amount);
        pushPullModule.addReward(user, address(token2), amount);
        pushPullModule.addReward(user, address(token3), amount);

        address[] memory tokens = new address[](3);
        tokens[0] = address(token1);
        tokens[1] = address(token2);
        tokens[2] = address(token3);

        if (amount % 2 == 0) {
            vm.prank(user);
            pushPullModule.pullRewards(tokens);
        } else {
            pushPullModule.pullRewards(user, tokens);
        }

        assertEq(0, pushPullModule.getPendingAmount(user, address(token1)));
        assertEq(0, pushPullModule.getPendingAmount(user, address(token2)));
        assertEq(0, pushPullModule.getPendingAmount(user, address(token3)));
        assertEq(amount, token1.balanceOf(user));
        assertEq(amount, token2.balanceOf(user));
        assertEq(amount, token3.balanceOf(user));

        assertEq(0, pushPullModule.getTotalPending(address(token1)));
        assertEq(0, pushPullModule.getTotalPending(address(token2)));
        assertEq(0, pushPullModule.getTotalPending(address(token3)));
    }
}

contract MockPushPull is PushPullModule {
    function addReward(address user, address token, uint256 amount) public {
        _pushReward(user, token, amount);
    }
}
