// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";
import {Ownable} from "solady/auth/Ownable.sol";
import {ReferralRegistry} from "src/registry/ReferralRegistry.sol";

contract ReferralRegistryTest is Test {
    /// @dev The module we will test
    ReferralRegistry private referralRegistry;

    address private owner = makeAddr("owner");

    /// @dev a few test users
    address private alice;
    address private bob;
    address private charlie;

    /// @dev a few test users private keys
    uint256 private alicePrivKey;
    uint256 private bobPrivKey;
    uint256 private charliePrivKey;

    bytes32 private TREE_1 = keccak256("tree1");
    bytes32 private TREE_2 = keccak256("tree2");

    address private tree1Owner = makeAddr("tree1Owner");
    address private tree2Owner = makeAddr("tree2Owner");

    function setUp() public {
        referralRegistry = new ReferralRegistry(owner);

        (alice, alicePrivKey) = makeAddrAndKey("alice");
        (bob, bobPrivKey) = makeAddrAndKey("bob");
        (charlie, charliePrivKey) = makeAddrAndKey("charlie");

        // Allow the owner on every tree we will user
        vm.prank(owner);
        referralRegistry.grantAccessToTree(TREE_1, tree1Owner);
        vm.prank(owner);
        referralRegistry.grantAccessToTree(TREE_2, tree2Owner);
    }

    function test_saveReferrer_InvalidReferrer() public {
        vm.expectRevert(ReferralRegistry.InvalidReferrer.selector);
        vm.prank(tree1Owner);
        referralRegistry.saveReferrer(TREE_1, alice, address(0));
    }

    function test_saveReferrer_NotAllowedOnTheGivenTree() public {
        vm.expectRevert(ReferralRegistry.NotAllowedOnTheGivenTree.selector);
        referralRegistry.saveReferrer(TREE_1, alice, bob);
    }

    function test_saveReferrer_chain() public {
        // First level of the chain, bob is referrer of alice
        vm.prank(tree1Owner);
        referralRegistry.saveReferrer(TREE_1, alice, bob);
        assertEq(bob, referralRegistry.getReferrer(TREE_1, alice));

        // Second level of the chain, charlie is referrer of bob
        vm.prank(tree1Owner);
        referralRegistry.saveReferrer(TREE_1, bob, charlie);
        assertEq(charlie, referralRegistry.getReferrer(TREE_1, bob));

        // Ensure every referrer of alice
        address[] memory referrers = referralRegistry.getAllReferrers(TREE_1, alice);
        assertEq(referrers.length, 2);
        assertEq(referrers[0], bob);
        assertEq(referrers[1], charlie);
    }

    function test_getCappedReferrers() public {
        // First level of the chain, bob is referrer of alice
        vm.startPrank(tree1Owner);
        referralRegistry.saveReferrer(TREE_1, alice, bob);
        referralRegistry.saveReferrer(TREE_1, bob, charlie);
        vm.stopPrank();

        // Ensure our capped list is ok
        address[] memory referrers = referralRegistry.getCappedReferrers(TREE_1, alice, 10);
        assertEq(referrers.length, 2);
        assertEq(referrers[0], bob);
        assertEq(referrers[1], charlie);

        // Ensure that the cap is respected and order keeped
        referrers = referralRegistry.getCappedReferrers(TREE_1, alice, 1);
        assertEq(referrers.length, 1);
        assertEq(referrers[0], bob);
    }

    function test_saveReferrer_multi() public {
        // First level of the chain, bob is referrer of alice
        vm.prank(tree1Owner);
        referralRegistry.saveReferrer(TREE_1, alice, charlie);
        assertEq(charlie, referralRegistry.getReferrer(TREE_1, alice));

        vm.prank(tree1Owner);
        referralRegistry.saveReferrer(TREE_1, bob, charlie);
        assertEq(charlie, referralRegistry.getReferrer(TREE_1, bob));
    }

    function test_saveReferrer_tree() public {
        // First level of the chain, bob is referrer of alice
        vm.prank(tree1Owner);
        referralRegistry.saveReferrer(TREE_1, alice, bob);
        assertEq(bob, referralRegistry.getReferrer(TREE_1, alice));

        vm.prank(tree2Owner);
        referralRegistry.saveReferrer(TREE_2, alice, charlie);
        assertEq(charlie, referralRegistry.getReferrer(TREE_2, alice));
    }

    function test_saveReferrer_AlreadyHaveReferer() public {
        // First level of the chain, bob is referrer of alice
        vm.prank(tree1Owner);
        referralRegistry.saveReferrer(TREE_1, alice, bob);
        vm.prank(tree1Owner);
        referralRegistry.saveReferrer(TREE_1, bob, charlie);

        // Ensure we can't add another referrer for alice on this tree
        vm.expectRevert(abi.encodeWithSelector(ReferralRegistry.AlreadyHaveReferer.selector, TREE_1, bob));
        vm.prank(tree1Owner);
        referralRegistry.saveReferrer(TREE_1, alice, bob);

        // Ensure we can't add another referrer for alice on this tree
        vm.expectRevert(abi.encodeWithSelector(ReferralRegistry.AlreadyHaveReferer.selector, TREE_1, bob));
        vm.prank(tree1Owner);
        referralRegistry.saveReferrer(TREE_1, alice, charlie);

        // Ensure we can't add another referrer for alice on this tree
        vm.expectRevert(abi.encodeWithSelector(ReferralRegistry.AlreadyHaveReferer.selector, TREE_1, charlie));
        vm.prank(tree1Owner);
        referralRegistry.saveReferrer(TREE_1, bob, alice);
    }

    function test_saveReferrer_AlreadyInRefererChain() public {
        // First level of the chain, bob is referrer of alice
        vm.prank(tree1Owner);
        referralRegistry.saveReferrer(TREE_1, alice, bob);
        vm.prank(tree1Owner);
        referralRegistry.saveReferrer(TREE_1, bob, charlie);

        vm.expectRevert(abi.encodeWithSelector(ReferralRegistry.AlreadyInRefererChain.selector, TREE_1));
        vm.prank(tree1Owner);
        referralRegistry.saveReferrer(TREE_1, charlie, alice);

        vm.expectRevert(abi.encodeWithSelector(ReferralRegistry.AlreadyInRefererChain.selector, TREE_1));
        vm.prank(tree1Owner);
        referralRegistry.saveReferrer(TREE_1, charlie, bob);
    }

    function test_transferAccessToTree() public {
        // Ensure that anyone that isn't the owner can't transfer the access
        vm.expectRevert(ReferralRegistry.NotAllowedOnTheGivenTree.selector);
        referralRegistry.transferAccessToTree(TREE_1, tree2Owner);
        assertEq(referralRegistry.isAllowedOnTree(TREE_1, tree2Owner), false);

        // Ensure that anyone that isn't the owner can't transfer the access
        vm.expectRevert(ReferralRegistry.InvalidTreeOwner.selector);
        referralRegistry.transferAccessToTree(TREE_1, address(0));
        assertEq(referralRegistry.isAllowedOnTree(TREE_1, tree2Owner), false);

        // Ensure that the owner can transfer the access
        vm.prank(tree1Owner);
        referralRegistry.transferAccessToTree(TREE_1, tree2Owner);
        assertEq(referralRegistry.isAllowedOnTree(TREE_1, tree2Owner), true);

        // Ensure new owner can add stuff to the chain
        vm.prank(tree2Owner);
        referralRegistry.saveReferrer(TREE_1, alice, charlie);
        assertEq(charlie, referralRegistry.getReferrer(TREE_1, alice));
    }

    function test_grantAccessToTree() public {
        // Ensure that anyone that isn't the owner can't transfer the access
        vm.expectRevert(Ownable.Unauthorized.selector);
        referralRegistry.grantAccessToTree(keccak256("test"), tree1Owner);
    }
}
