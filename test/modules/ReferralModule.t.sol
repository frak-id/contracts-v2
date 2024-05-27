// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ReferralModule} from "src/modules/ReferralModule.sol";
import {InvalidSignature} from "src/constants/Errors.sol";
import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";
import {Test} from "forge-std/Test.sol";

contract ReferralModuleTest is Test {
    /// @dev The module we will test
    MockReferral private referralModule;

    /// @dev a few test users
    address alice;
    address bob;
    address charlie;

    /// @dev a few test users private keys
    uint256 alicePrivKey;
    uint256 bobPrivKey;
    uint256 charliePrivKey;

    bytes32 TREE_1 = bytes32(0);
    bytes32 TREE_2 = keccak256("tree2");

    function setUp() public {
        referralModule = new MockReferral();

        (alice, alicePrivKey) = makeAddrAndKey("alice");
        (bob, bobPrivKey) = makeAddrAndKey("bob");
        (charlie, charliePrivKey) = makeAddrAndKey("charlie");
    }

    function test_saveReferrer_InvalidReferrer() public {
        vm.expectRevert(ReferralModule.InvalidReferrer.selector);
        referralModule.saveReferrer("tree", alice, address(0));
    }

    function test_saveReferrer_chain() public {
        // First level of the chain, bob is referrer of alice
        referralModule.saveReferrer(TREE_1, alice, bob);
        assertEq(referralModule.getCallbackCounter(), 1);
        assertEq(bob, referralModule.getReferrer(TREE_1, alice));

        // Second level of the chain, charlie is referrer of bob
        referralModule.saveReferrer(TREE_1, bob, charlie);
        assertEq(referralModule.getCallbackCounter(), 2);
        assertEq(charlie, referralModule.getReferrer(TREE_1, bob));

        // Ensure every referrer of alice
        address[] memory referrers = referralModule.getAllReferrers(TREE_1, alice);
        assertEq(referrers.length, 2);
        assertEq(referrers[0], bob);
        assertEq(referrers[1], charlie);
    }

    function test_saveReferrer_multi() public {
        // First level of the chain, bob is referrer of alice
        referralModule.saveReferrer(TREE_1, alice, charlie);
        assertEq(referralModule.getCallbackCounter(), 1);
        assertEq(charlie, referralModule.getReferrer(TREE_1, alice));

        referralModule.saveReferrer(TREE_1, bob, charlie);
        assertEq(referralModule.getCallbackCounter(), 2);
        assertEq(charlie, referralModule.getReferrer(TREE_1, bob));
    }

    function test_saveReferrer_tree() public {
        // First level of the chain, bob is referrer of alice
        referralModule.saveReferrer(TREE_1, alice, bob);
        assertEq(referralModule.getCallbackCounter(), 1);
        assertEq(bob, referralModule.getReferrer(TREE_1, alice));

        referralModule.saveReferrer(TREE_2, alice, charlie);
        assertEq(referralModule.getCallbackCounter(), 2);
        assertEq(charlie, referralModule.getReferrer(TREE_2, alice));
    }

    function test_saveReferrer_AlreadyHaveReferer() public {
        // First level of the chain, bob is referrer of alice
        referralModule.saveReferrer(TREE_1, alice, bob);
        referralModule.saveReferrer(TREE_1, bob, charlie);

        // Ensure we can't add another referrer for alice on this tree
        vm.expectRevert(abi.encodeWithSelector(ReferralModule.AlreadyHaveReferer.selector, TREE_1, bob));
        referralModule.saveReferrer(TREE_1, alice, bob);

        // Ensure we can't add another referrer for alice on this tree
        vm.expectRevert(abi.encodeWithSelector(ReferralModule.AlreadyHaveReferer.selector, TREE_1, bob));
        referralModule.saveReferrer(TREE_1, alice, charlie);

        // Ensure we can't add another referrer for alice on this tree
        vm.expectRevert(abi.encodeWithSelector(ReferralModule.AlreadyHaveReferer.selector, TREE_1, charlie));
        referralModule.saveReferrer(TREE_1, bob, alice);
    }

    function test_saveReferrer_AlreadyInRefererChain() public {
        // First level of the chain, bob is referrer of alice
        referralModule.saveReferrer(TREE_1, alice, bob);
        referralModule.saveReferrer(TREE_1, bob, charlie);

        vm.expectRevert(abi.encodeWithSelector(ReferralModule.AlreadyInRefererChain.selector, TREE_1));
        referralModule.saveReferrer(TREE_1, charlie, alice);

        vm.expectRevert(abi.encodeWithSelector(ReferralModule.AlreadyInRefererChain.selector, TREE_1));
        referralModule.saveReferrer(TREE_1, charlie, bob);
    }

    function test_saveReferrerViaSignature_InvalidSignature() public {
        bytes memory signature = SignatureCheckerLib.emptySignature();

        vm.expectRevert(InvalidSignature.selector);
        referralModule.saveReferrerViaSignature(TREE_1, alice, bob, signature);

        signature = _getSaveReferrerSignature(TREE_1, charliePrivKey, alice, bob);
        vm.expectRevert(InvalidSignature.selector);
        referralModule.saveReferrerViaSignature(TREE_1, alice, bob, signature);
    }

    function test_saveReferrerViaSignature() public {
        bytes memory signature = _getSaveReferrerSignature(TREE_1, alicePrivKey, alice, bob);
        referralModule.saveReferrerViaSignature(TREE_1, alice, bob, signature);

        signature = _getSaveReferrerSignature(TREE_1, bobPrivKey, bob, charlie);
        referralModule.saveReferrerViaSignature(TREE_1, bob, charlie, signature);

        signature = _getSaveReferrerSignature(TREE_1, charliePrivKey, charlie, alice);
        vm.expectRevert(abi.encodeWithSelector(ReferralModule.AlreadyInRefererChain.selector, TREE_1));
        referralModule.saveReferrerViaSignature(TREE_1, charlie, alice, signature);
    }

    /* -------------------------------------------------------------------------- */
    /*                               Signature utils                              */
    /* -------------------------------------------------------------------------- */

    function _getSaveReferrerSignature(bytes32 tree, uint256 userPrivKey, address user, address referrer)
        private
        view
        returns (bytes memory signature)
    {
        bytes32 domainHash = keccak256(
            abi.encode(
                // Domain hash
                0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f,
                keccak256("FrakModule.Referral"),
                keccak256("0.0.1"),
                block.chainid,
                address(referralModule)
            )
        );
        bytes32 dataHash = keccak256(
            abi.encode(keccak256("SaveReferrer(bytes32 tree,address user,address referrer)"), tree, user, referrer)
        );
        bytes32 fullHash = keccak256(abi.encodePacked("\x19\x01", domainHash, dataHash));

        // Sign the full hash
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivKey, fullHash);
        if (v != 27) {
            // then left-most bit of s has to be flipped to 1.
            s = s | bytes32(uint256(1) << 255);
        }

        // Compact the signature into a single byte
        signature = abi.encodePacked(r, s);
    }
}

contract MockReferral is ReferralModule {
    uint256 private callbackCounter;

    function saveReferrer(bytes32 _tree, address _user, address _referrer) public {
        _saveReferrer(_tree, _user, _referrer);
    }

    function saveReferrerViaSignature(bytes32 _tree, address _user, address _referrer, bytes calldata _signature)
        public
    {
        _saveReferrerViaSignature(_tree, _user, _referrer, _signature);
    }

    function onUserReferred(bytes32, address, address) internal override {
        callbackCounter++;
    }

    function getCallbackCounter() public view returns (uint256) {
        return callbackCounter;
    }
}
