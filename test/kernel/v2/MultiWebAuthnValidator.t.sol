// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEntryPoint} from "I4337/interfaces/IEntryPoint.sol";
import "kernel-v2/Kernel.sol";
import "forge-std/Test.sol";
import {ERC4337Utils} from "kernel-v2/utils/ERC4337Utils.sol";
import {KernelTestBase} from "kernel-v2/utils/KernelTestBase.sol";
import {TestExecutor} from "kernel-v2/mock/TestExecutor.sol";
import {TestValidator} from "kernel-v2/mock/TestValidator.sol";
import {FCL_ecdsa_utils} from "FreshCryptoLib/FCL_ecdsa_utils.sol";
import {Base64Url} from "FreshCryptoLib/utils/Base64Url.sol";
import {IKernel} from "kernel-v2/interfaces/IKernel.sol";
import {WebAuthnVerifier} from "src/kernel/utils/WebAuthnVerifier.sol";
import {P256VerifierWrapper} from "src/kernel/utils/P256VerifierWrapper.sol";
import {MultiWebAuthNValidatorV2, WebAuthNPubKey} from "src/kernel/v2/MultiWebAuthNValidator.sol";

using ERC4337Utils for IEntryPoint;

contract WebAuthnFclValidatorTest is KernelTestBase {
    MultiWebAuthNValidatorV2 private webAuthNValidator;
    WebAuthNTester private webAuthNTester;
    P256VerifierWrapper private p256VerifierWrapper;

    // Curve order (number of points)
    uint256 constant n = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;

    // The public key of the owner
    bytes32 authenticatorId;
    uint256 x;
    uint256 y;

    function setUp() public {
        // Deploy a RIP-7212 compliant P256Verifier contract
        p256VerifierWrapper = new P256VerifierWrapper();
        // Deploy a WebAuthnFclValidator contract using that RIP-7212 compliant P256Verifier contract
        webAuthNValidator = new MultiWebAuthNValidatorV2(address(p256VerifierWrapper));

        // Deploy a webAuthNTester that will be used to format the signature during test
        webAuthNTester = new WebAuthNTester();

        _initialize();
        authenticatorId = keccak256("authenticatorId");
        (x, y) = _getPublicKey(ownerKey);
        _setAddress();
        _setExecutionDetail();
    }

    function _setExecutionDetail() internal virtual override {
        executionDetail.executor = address(new TestExecutor());
        executionSig = TestExecutor.doNothing.selector;
        executionDetail.validator = new TestValidator();
    }

    function getValidatorSignature(UserOperation memory _op) internal view virtual override returns (bytes memory) {
        bytes32 _hash = entryPoint.getUserOpHash(_op);
        bytes memory signature = _generateWebAuthnSignature(ownerKey, _hash);
        return abi.encodePacked(bytes4(0x00000000), signature);
    }

    function getOwners() internal virtual override returns (address[] memory _owners) {
        _owners = new address[](1);
        _owners[0] = address(0);
        return _owners;
    }

    function getEnableData() internal view virtual override returns (bytes memory) {
        return "";
    }

    function getInitializeData() internal view override returns (bytes memory) {
        return abi.encodeWithSelector(
            KernelStorage.initialize.selector, webAuthNValidator, abi.encode(authenticatorId, x, y)
        );
    }

    function test_default_validator_enable() external override {
        UserOperation memory op = buildUserOperation(
            abi.encodeWithSelector(
                IKernel.execute.selector,
                address(webAuthNValidator),
                0,
                abi.encodeWithSelector(webAuthNValidator.enable.selector, abi.encode(authenticatorId, x, y)),
                Operation.Call
            )
        );
        performUserOperationWithSig(op);
        (, WebAuthNPubKey memory pubKey) =
            MultiWebAuthNValidatorV2(address(webAuthNValidator)).getPasskey(address(kernel));
        _assertPublicKey(pubKey.x, pubKey.y, x, y);
    }

    function test_default_validator_disable() external override {
        UserOperation memory op = buildUserOperation(
            abi.encodeWithSelector(
                IKernel.execute.selector,
                address(webAuthNValidator),
                0,
                abi.encodeWithSelector(webAuthNValidator.disable.selector, ""),
                Operation.Call
            )
        );
        performUserOperationWithSig(op);
        (, WebAuthNPubKey memory pubKey) =
            MultiWebAuthNValidatorV2(address(webAuthNValidator)).getPasskey(address(kernel));
        _assertPublicKey(pubKey.x, pubKey.y, 0, 0);
    }

    function test_external_call_batch_execute_success() external override {
        vm.skip(true);
    }

    function test_external_call_execute_success() external override {
        vm.skip(true);
    }

    function test_external_call_execute_delegatecall_success() external override {
        vm.skip(true);
    }

    function test_external_call_execute_delegatecall_fail() external override {
        vm.skip(true);
    }

    function test_external_call_default() external override {
        vm.skip(true);
    }

    function test_external_call_execution() external override {
        vm.skip(true);
    }

    function test_validate_signature() external view override {
        bytes32 _hash = keccak256(abi.encodePacked("hello world"));

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01", ERC4337Utils._buildDomainSeparator(KERNEL_NAME, KERNEL_VERSION, address(kernel)), _hash
            )
        );

        bytes memory signature = signHash(digest);

        assertEq(kernel.isValidSignature(_hash, signature), Kernel.isValidSignature.selector);
    }

    function test_fail_validate_wrongsignature() external view override {
        // Prepare the hash to sign
        bytes32 _hash = keccak256(abi.encodePacked("hello world"));
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01", ERC4337Utils._buildDomainSeparator(KERNEL_NAME, KERNEL_VERSION, address(kernel)), _hash
            )
        );

        // Sign it (via a wrong signer)
        bytes memory sig = getWrongSignature(digest);
        assertEq(kernel.isValidSignature(_hash, sig), bytes4(0xffffffff));
    }

    function test_fail_validate_InvalidWebAuthnData() external {
        // Prepare the data to sign
        bytes32 _hash = keccak256(abi.encodePacked("hello world"));
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01", ERC4337Utils._buildDomainSeparator(KERNEL_NAME, KERNEL_VERSION, address(kernel)), _hash
            )
        );

        bytes32 _wrongHash = keccak256(abi.encodePacked("bye world"));

        // Sign it
        bytes memory sig = signHash(digest);

        // Ensure it's reverting
        vm.expectRevert("Kernel::_validateSignature: failed to validate signature");
        kernel.isValidSignature(_wrongHash, sig);
    }

    function signUserOp(UserOperation memory op) internal view override returns (bytes memory) {
        bytes32 _hash = entryPoint.getUserOpHash(op);
        bytes memory signature = _generateWebAuthnSignature(ownerKey, _hash);
        return abi.encodePacked(bytes4(0x00000000), signature);
    }

    function getWrongSignature(UserOperation memory op) internal view override returns (bytes memory) {
        bytes32 _hash = entryPoint.getUserOpHash(op);
        bytes memory signature = _generateWebAuthnSignature(ownerKey + 1, _hash);
        return abi.encodePacked(bytes4(0x00000000), signature);
    }

    function signHash(bytes32 _hash) internal view override returns (bytes memory) {
        return _generateWebAuthnSignature(ownerKey, _hash);
    }

    function getWrongSignature(bytes32 _hash) internal view override returns (bytes memory) {
        return _generateWebAuthnSignature(ownerKey + 1, _hash);
    }

    function _assertPublicKey(uint256 actualX, uint256 actualY, uint256 expectedX, uint256 expectedY) internal pure {
        assertEq(actualX, expectedX, "Public key X component mismatch");
        assertEq(actualY, expectedY, "Public key Y component mismatch");
    }

    /// @dev Ensure that the validation won't revert when using the dummy signature bypass (challenge offset to uint256.max)
    function test_dontRevertForDummySig() public view {
        // Build rly dummy data for authenticator data and client data
        bytes memory authenticatorData = hex"1312";
        bytes memory clientData = hex"1312";

        // Build an incoherent signature
        bytes memory rawSignature = _packWebAuthNSignature(
            type(uint256).max, type(uint256).max, type(uint256).max, authenticatorData, clientData
        );

        // Check the sig (and ensure we didn't revert here)
        bool isValid = webAuthNTester.verifySignature(address(p256VerifierWrapper), bytes32(0), rawSignature, x, y);
        assertEq(isValid, false);

        // Ensure we can go through the validator with that signature
        bytes memory signature = abi.encodePacked(false, authenticatorId, rawSignature);

        // Ensure we can go through the validator with that signature
        ValidationData validationData = webAuthNValidator.validateSignature(bytes32(0), signature);
        assertEq(ValidationData.unwrap(validationData), 1);
    }

    /// @dev Ensure that our flow to generate a webauthn signature is working
    function test_webAuthnSignatureGeneration(bytes32 _hash, uint256 _privateKey) public view {
        vm.assume(_privateKey > 1);
        vm.assume(_privateKey < n);
        (uint256 pubX, uint256 pubY) = _getPublicKey(_privateKey);

        // Build all the data required
        (bytes32 msgToSign, bytes memory authenticatorData, bytes memory clientData, uint256 clientChallengeDataOffset)
        = _prepapreWebAuthnMsg(_hash);

        // Then sign them
        (uint256 r, uint256 s) = _getP256Signature(_privateKey, msgToSign);

        // Encode all of that into a signature
        bytes memory signature = _packWebAuthNSignature(clientChallengeDataOffset, r, s, authenticatorData, clientData);

        // Ensure the signature is valid
        bool isValid = webAuthNTester.verifySignature(address(p256VerifierWrapper), _hash, signature, pubX, pubY);
        assertEq(isValid, true);
    }

    /// @dev Ensure that our flow to generate a webauthn signature is working
    function test_webAuthnSignatureGeneration_solo() public view {
        uint256 _privateKey = 0xdeadbeef;
        bytes32 _hash = keccak256(abi.encodePacked("hello world"));
        (uint256 pubX, uint256 pubY) = _getPublicKey(_privateKey);

        // Build all the data required
        (bytes32 msgToSign, bytes memory authenticatorData, bytes memory clientData, uint256 clientChallengeDataOffset)
        = _prepapreWebAuthnMsg(_hash);

        // Then sign them
        (uint256 r, uint256 s) = _getP256Signature(_privateKey, msgToSign);

        // Encode all of that into a signature
        bytes memory signature = _packWebAuthNSignature(clientChallengeDataOffset, r, s, authenticatorData, clientData);

        // Ensure the signature is valid
        bool isValid = webAuthNTester.verifySignature(address(p256VerifierWrapper), _hash, signature, pubX, pubY);
        assertEq(isValid, true);
    }

    /* -------------------------------------------------------------------------- */
    /*                      Signature & P256 helper functions                     */
    /* -------------------------------------------------------------------------- */

    /// @dev Generate a webauthn signature for the given `_hash` using the given `_privateKey`
    function _generateWebAuthnSignature(uint256 _privateKey, bytes32 _hash)
        internal
        view
        returns (bytes memory signature)
    {
        (bytes32 msgToSign, bytes memory authenticatorData, bytes memory clientData, uint256 clientChallengeDataOffset)
        = _prepapreWebAuthnMsg(_hash);
        console.log("Challenge offset: %x", clientChallengeDataOffset);
        console.log("Challenge to sign: %x", uint256(msgToSign));
        console.log("Authenticator data (legth: %x)", authenticatorData.length);
        console.logBytes(authenticatorData);

        // Get the signature
        (uint256 r, uint256 s) = _getP256Signature(_privateKey, msgToSign);

        // The fcl signature directly
        bytes memory webAuthNSignature =
            _packWebAuthNSignature(clientChallengeDataOffset, r, s, authenticatorData, clientData);

        // Return the signature + metadata
        return abi.encodePacked(false, authenticatorId, webAuthNSignature);
    }

    /// @dev Prepare all the base data needed to perform a webauthn signature o n the given `_hash`
    function _prepapreWebAuthnMsg(bytes32 _hash)
        internal
        view
        returns (
            bytes32 msgToSign,
            bytes memory authenticatorData,
            bytes memory clientData,
            uint256 clientChallengeDataOffset
        )
    {
        // Base Mapping of the message
        bytes memory encodedChallenge = bytes(Base64Url.encode(abi.encodePacked(_hash)));

        // Prepare the authenticator data (from a real webauthn challenge)
        authenticatorData = hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97630500000000";

        // Prepare the client data (starting from a real webauthn challenge, then replacing only the bytes needed for the challenge)
        bytes memory clientDataStart = hex"7b2274797065223a22776562617574686e2e676574222c226368616c6c656e6765223a22";
        bytes memory clientDataEnd =
            hex"222c226f726967696e223a22687474703a2f2f6c6f63616c686f73743a33303032222c2263726f73734f726967696e223a66616c73657d";
        clientData = bytes.concat(clientDataStart, encodedChallenge, clientDataEnd);
        clientChallengeDataOffset = 36;

        // Build the signature layout
        bytes memory sigForFormat =
            _packWebAuthNSignature(clientChallengeDataOffset, 0, 0, authenticatorData, clientData);

        // Format it
        msgToSign = webAuthNTester.formatSigLayout(_hash, sigForFormat);
    }

    /// @dev Get a public key for a p256 user, from the given `_privateKey`
    function _getPublicKey(uint256 _privateKey) internal view returns (uint256, uint256) {
        return FCL_ecdsa_utils.ecdsa_derivKpub(_privateKey);
    }

    /// P256 curve order n/2 for malleability check
    uint256 constant P256_N_DIV_2 = 57896044605178124381348723474703786764998477612067880171211129530534256022184;

    /// @dev Generate a p256 signature, from the given `_privateKey` on the given `_hash`
    function _getP256Signature(uint256 _privateKey, bytes32 _hash) internal pure returns (uint256, uint256) {
        // Generate the signature using the k value and the private key
        (bytes32 r, bytes32 s) = vm.signP256(_privateKey, _hash);
        return (uint256(r), uint256(s));
    }

    function _packWebAuthNSignature(
        uint256 challengeOffset,
        uint256 r,
        uint256 s,
        bytes memory authenticatorData,
        bytes memory clientData
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(
            // Challenge offset
            challengeOffset,
            // R + S
            r,
            s,
            // Length of both
            uint24(authenticatorData.length),
            uint24(clientData.length),
            // Data themself
            authenticatorData,
            clientData
        );
    }
}

/// @dev simple contract to format a webauthn challenge (using to convert stuff in memory during test to calldata)
contract WebAuthNTester {
    function formatSigLayout(bytes32 _hash, bytes calldata signatureLayout) public pure returns (bytes32) {
        return WebAuthnVerifier._formatWebAuthNChallenge(_hash, signatureLayout);
    }

    function verifySignature(address _p256Verifier, bytes32 _hash, bytes calldata _signature, uint256 _x, uint256 _y)
        public
        view
        returns (bool)
    {
        return WebAuthnVerifier._verifyWebAuthNSignature(_p256Verifier, _hash, _signature, _x, _y);
    }
}
