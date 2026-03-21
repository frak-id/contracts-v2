// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {MoneriumSignMsgAction} from "src/kernel/monerium/MoneriumSignMsgAction.sol";

/// @dev Minimal wallet mock that delegatecalls to an action contract, simulating Kernel v2's fallback() behavior.
contract MockKernelWallet {
    address public action;

    constructor(address _action) {
        action = _action;
    }

    receive() external payable {}

    fallback() external payable {
        address _action = action;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), _action, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

contract MoneriumSignMsgActionTest is Test {
    MoneriumSignMsgAction private action;
    MockKernelWallet private wallet;

    /// @dev Mirror of the event in MoneriumSignMsgAction — used for expectEmit
    event SignMsg(bytes32 indexed msgHash);

    /// @dev The Monerium link message
    bytes private constant LINK_MESSAGE = "I hereby declare that I am the address owner.";

    function setUp() public {
        action = new MoneriumSignMsgAction();
        wallet = new MockKernelWallet(address(action));
    }

    /* -------------------------------------------------------------------------- */
    /*                         Hash Computation Tests                             */
    /* -------------------------------------------------------------------------- */

    function test_getMessageHash_matchesSafeFormat() public view {
        // Compute expected hash following Safe's SignMessageLib.getMessageHash() exactly
        bytes32 safeMsgTypehash = 0x60b3cbf8b4a223d68d641b3b6ddf9a298e7f33710cf3d3a9d1146b5a6150fbca;
        bytes32 domainTypehash = 0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

        // When called directly on the action, address(this) = action contract
        bytes32 expected = keccak256(
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                keccak256(abi.encode(domainTypehash, block.chainid, address(action))),
                keccak256(abi.encode(safeMsgTypehash, keccak256(LINK_MESSAGE)))
            )
        );

        bytes32 actual = action.getMessageHash(LINK_MESSAGE);
        assertEq(actual, expected, "Hash should match Safe's EIP-712 format");
    }

    function test_getMessageHash_viaDelegatecall_usesWalletAddress() public view {
        // When called via delegatecall (through wallet), address(this) = wallet address
        // So the domain separator should use the wallet's address
        bytes32 safeMsgTypehash = 0x60b3cbf8b4a223d68d641b3b6ddf9a298e7f33710cf3d3a9d1146b5a6150fbca;
        bytes32 domainTypehash = 0x47e79534a245952e8b16893a336b85a3d9ea9fa8c573f3d803afb92a79469218;

        bytes32 expectedWithWalletAddress = keccak256(
            abi.encodePacked(
                bytes1(0x19),
                bytes1(0x01),
                keccak256(abi.encode(domainTypehash, block.chainid, address(wallet))),
                keccak256(abi.encode(safeMsgTypehash, keccak256(LINK_MESSAGE)))
            )
        );

        // Call getMessageHash via the wallet (delegatecall)
        bytes32 actual = MoneriumSignMsgAction(address(wallet)).getMessageHash(LINK_MESSAGE);
        assertEq(actual, expectedWithWalletAddress, "Delegatecall hash should use wallet address in domain separator");
    }

    function test_getMessageHash_differentChainId() public {
        // Verify chain ID is included in the hash
        bytes32 hash1 = action.getMessageHash(LINK_MESSAGE);

        // Change chain ID
        vm.chainId(42_161); // Arbitrum
        bytes32 hash2 = action.getMessageHash(LINK_MESSAGE);

        assertTrue(hash1 != hash2, "Different chain IDs should produce different hashes");
    }

    function test_getMessageHash_differentMessages() public view {
        bytes32 hash1 = action.getMessageHash(LINK_MESSAGE);
        bytes32 hash2 = action.getMessageHash("Some other message");

        assertTrue(hash1 != hash2, "Different messages should produce different hashes");
    }

    /* -------------------------------------------------------------------------- */
    /*                       signMessage (Safe Format) Tests                      */
    /* -------------------------------------------------------------------------- */

    function test_signMessage_emitsSignMsgEvent() public {
        // Compute expected hash (using wallet address since it goes through delegatecall)
        bytes32 expectedHash = MoneriumSignMsgAction(address(wallet)).getMessageHash(LINK_MESSAGE);

        // Expect the SignMsg event from the wallet address
        vm.expectEmit(true, false, false, false, address(wallet));
        emit SignMsg(expectedHash);

        // Call signMessage through the wallet (delegatecall)
        MoneriumSignMsgAction(address(wallet)).signMessage(LINK_MESSAGE);
    }

    function test_signMessage_storesSignedHash() public {
        // Sign the message through the wallet
        MoneriumSignMsgAction(address(wallet)).signMessage(LINK_MESSAGE);

        // Check the hash is stored (via delegatecall, reads wallet's storage)
        bytes32 msgHash = MoneriumSignMsgAction(address(wallet)).getMessageHash(LINK_MESSAGE);
        bool isSigned = MoneriumSignMsgAction(address(wallet)).isSignedMessage(msgHash);
        assertTrue(isSigned, "Message hash should be marked as signed in wallet storage");
    }

    function test_signMessage_unsignedHashReturnsFalse() public view {
        bytes32 unsignedHash = keccak256("not signed");
        bool isSigned = MoneriumSignMsgAction(address(wallet)).isSignedMessage(unsignedHash);
        assertFalse(isSigned, "Unsigned hash should return false");
    }

    function test_signMessage_revertsOnEmptyMessage() public {
        vm.expectRevert(MoneriumSignMsgAction.EmptyMessage.selector);
        MoneriumSignMsgAction(address(wallet)).signMessage("");
    }

    /* -------------------------------------------------------------------------- */
    /*                        signMessageRaw (Raw Hash) Tests                     */
    /* -------------------------------------------------------------------------- */

    function test_signMessageRaw_emitsSignMsgEvent() public {
        bytes32 rawHash = keccak256(LINK_MESSAGE);

        vm.expectEmit(true, false, false, false, address(wallet));
        emit SignMsg(rawHash);

        MoneriumSignMsgAction(address(wallet)).signMessageRaw(rawHash);
    }

    function test_signMessageRaw_storesSignedHash() public {
        bytes32 rawHash = keccak256(LINK_MESSAGE);

        MoneriumSignMsgAction(address(wallet)).signMessageRaw(rawHash);

        bool isSigned = MoneriumSignMsgAction(address(wallet)).isSignedMessage(rawHash);
        assertTrue(isSigned, "Raw hash should be marked as signed");
    }

    function test_signMessageRaw_arbitraryHash() public {
        bytes32 arbitraryHash = bytes32(uint256(0xdeadbeef));

        vm.expectEmit(true, false, false, false, address(wallet));
        emit SignMsg(arbitraryHash);

        MoneriumSignMsgAction(address(wallet)).signMessageRaw(arbitraryHash);

        bool isSigned = MoneriumSignMsgAction(address(wallet)).isSignedMessage(arbitraryHash);
        assertTrue(isSigned, "Arbitrary hash should be storable and retrievable");
    }

    /* -------------------------------------------------------------------------- */
    /*                          Delegatecall Context Tests                        */
    /* -------------------------------------------------------------------------- */

    function test_eventEmitsFromWalletAddress() public {
        // This is the critical test: the event must come from the wallet address, not the action contract
        bytes32 rawHash = keccak256("test");

        // Record all logs
        vm.recordLogs();

        MoneriumSignMsgAction(address(wallet)).signMessageRaw(rawHash);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length, 1, "Should emit exactly one event");
        assertEq(logs[0].emitter, address(wallet), "Event must be emitted from wallet address");
        assertEq(logs[0].topics[0], keccak256("SignMsg(bytes32)"), "Event topic must be SignMsg");
        assertEq(logs[0].topics[1], bytes32(rawHash), "Event indexed param must be the msgHash");
    }

    function test_storageIsolation_betweenWallets() public {
        // Create a second wallet pointing to the same action
        MockKernelWallet wallet2 = new MockKernelWallet(address(action));

        bytes32 msgHash = keccak256("only for wallet 1");

        // Sign from wallet 1
        MoneriumSignMsgAction(address(wallet)).signMessageRaw(msgHash);

        // Verify wallet 1 has it signed
        assertTrue(
            MoneriumSignMsgAction(address(wallet)).isSignedMessage(msgHash), "Wallet 1 should have the message signed"
        );

        // Verify wallet 2 does NOT have it signed (ERC-7201 storage is per-wallet via delegatecall)
        assertFalse(
            MoneriumSignMsgAction(address(wallet2)).isSignedMessage(msgHash),
            "Wallet 2 should NOT have the message signed"
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                             Fuzz Tests                                     */
    /* -------------------------------------------------------------------------- */

    function testFuzz_signMessageRaw_anyHash(bytes32 _hash) public {
        vm.expectEmit(true, false, false, false, address(wallet));
        emit SignMsg(_hash);

        MoneriumSignMsgAction(address(wallet)).signMessageRaw(_hash);

        assertTrue(MoneriumSignMsgAction(address(wallet)).isSignedMessage(_hash));
    }

    function testFuzz_signMessage_anyData(bytes calldata _data) public {
        vm.assume(_data.length > 0);

        bytes32 expectedHash = MoneriumSignMsgAction(address(wallet)).getMessageHash(_data);

        vm.expectEmit(true, false, false, false, address(wallet));
        emit SignMsg(expectedHash);

        MoneriumSignMsgAction(address(wallet)).signMessage(_data);

        assertTrue(MoneriumSignMsgAction(address(wallet)).isSignedMessage(expectedHash));
    }
}
