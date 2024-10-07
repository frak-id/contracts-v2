// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {InteractionTest} from "../../interaction/InteractionTest.sol";
import {FCL_ecdsa_utils} from "FreshCryptoLib/FCL_ecdsa_utils.sol";
import {Base64Url} from "FreshCryptoLib/utils/Base64Url.sol";
import {IEntryPoint} from "I4337/interfaces/IEntryPoint.sol";
import "forge-std/Test.sol";
import "kernel-v2/Kernel.sol";
import {ExecutionDetail} from "kernel-v2/common/Structs.sol";
import {IKernel} from "kernel-v2/interfaces/IKernel.sol";
import {TestExecutor} from "kernel-v2/mock/TestExecutor.sol";
import {TestValidator} from "kernel-v2/mock/TestValidator.sol";
import {ERC4337Utils} from "kernel-v2/utils/ERC4337Utils.sol";
import {KernelTestBase} from "kernel-v2/utils/KernelTestBase.sol";
import {ECDSAValidator} from "kernel-v2/validator/ECDSAValidator.sol";
import {Ownable} from "solady/auth/Ownable.sol";

import {LibZip} from "solady/utils/LibZip.sol";
import {InteractionType, PressInteractions} from "src/constants/InteractionType.sol";
import {DENOMINATOR_PRESS, PRODUCT_TYPE_PRESS} from "src/constants/ProductTypes.sol";
import {ProductInteractionDiamond} from "src/interaction/ProductInteractionDiamond.sol";
import {PressInteractionFacet} from "src/interaction/facets/PressInteractionFacet.sol";
import {DELEGATION_EXECUTOR_ROLE, InteractionDelegator} from "src/kernel/interaction/InteractionDelegator.sol";
import {Interaction, InteractionDelegatorAction} from "src/kernel/interaction/InteractionDelegatorAction.sol";
import {InteractionDelegatorValidator} from "src/kernel/interaction/InteractionDelegatorValidator.sol";
import {P256VerifierWrapper} from "src/kernel/utils/P256VerifierWrapper.sol";
import {WebAuthnVerifier} from "src/kernel/utils/WebAuthnVerifier.sol";
import {MultiWebAuthNValidatorV2, WebAuthNPubKey} from "src/kernel/webauthn/MultiWebAuthNValidator.sol";

using ERC4337Utils for IEntryPoint;

contract InteractionDelegatorTest is KernelTestBase, InteractionTest {
    address private delegator = makeAddr("interactionDelegator");

    InteractionDelegator private interactionDelegator;
    InteractionDelegatorValidator private interactionDelegatorValidator;
    InteractionDelegatorAction private interactionDelegatorAction;

    function setUp() public {
        _initEcosystemAwareTest();

        // Deploy the interaction delegation stuff
        interactionDelegator = new InteractionDelegator(contractOwner);
        interactionDelegatorValidator = new InteractionDelegatorValidator(address(interactionDelegator));
        interactionDelegatorAction = new InteractionDelegatorAction(productInteractionManager);

        vm.prank(contractOwner);
        interactionDelegator.grantRoles(delegator, DELEGATION_EXECUTOR_ROLE);

        // Deploy the press interaction contract
        (uint256 _pid, ProductInteractionDiamond _productInteraction) =
            _mintProductWithInteraction(PRODUCT_TYPE_PRESS, "name", "press-domain");
        _initInteractionTest(_pid, _productInteraction);

        // Init the kernel test
        _initialize();
        defaultValidator = new ECDSAValidator();
        _setAddress();
        _setExecutionDetail();
    }

    /* -------------------------------------------------------------------------- */
    /*                           Delegation action test                           */
    /* -------------------------------------------------------------------------- */

    function test_enableInteractionDelegation() public withEnabledInteractionDelegation {
        // Ensure we got single execution registered
        ExecutionDetail memory execution = kernel.getExecution(InteractionDelegatorAction.sendInteraction.selector);
        assertEq(execution.executor, address(interactionDelegatorAction));
        assertEq(address(execution.validator), address(interactionDelegatorValidator));
        // Ensure we got batch execution registered
        execution = kernel.getExecution(InteractionDelegatorAction.sendInteractions.selector);
        assertEq(execution.executor, address(interactionDelegatorAction));
        assertEq(address(execution.validator), address(interactionDelegatorValidator));
    }

    function test_sendInteraction_NotAuthorizedCaller() public withEnabledInteractionDelegation {
        bytes memory handleInteractionData = _getHandleInteractionData();

        // Build the interaction to be sent
        Interaction memory interaction = Interaction(productId, handleInteractionData);

        // Send it
        vm.expectRevert(IKernel.NotAuthorizedCaller.selector);
        InteractionDelegatorAction(address(kernel)).sendInteraction(interaction);
    }

    function test_sendInteractions_NotAuthorizedCaller() public withEnabledInteractionDelegation {
        bytes memory handleInteractionData = _getHandleInteractionData();

        // Build the interaction to be sent
        Interaction[] memory interactions = new Interaction[](1);
        interactions[0] = Interaction(productId, handleInteractionData);

        // Send it
        vm.expectRevert(IKernel.NotAuthorizedCaller.selector);
        InteractionDelegatorAction(address(kernel)).sendInteractions(interactions);
    }

    function test_sendInteraction() public withEnabledInteractionDelegation {
        bytes memory handleInteractionData = _getHandleInteractionData();

        // Build the interaction to be sent
        Interaction memory interaction = Interaction(productId, handleInteractionData);

        // Send it
        vm.prank(address(interactionDelegator));
        InteractionDelegatorAction(address(kernel)).sendInteraction(interaction);
    }

    function test_sendInteractions() public withEnabledInteractionDelegation {
        bytes memory handleInteractionData = _getHandleInteractionData();

        // Build the interaction to be sent
        Interaction[] memory interactions = new Interaction[](1);
        interactions[0] = Interaction(productId, handleInteractionData);

        // Send it
        vm.prank(address(interactionDelegator));
        InteractionDelegatorAction(address(kernel)).sendInteractions(interactions);
    }

    /* -------------------------------------------------------------------------- */
    /*                         Delegated interaction test                         */
    /* -------------------------------------------------------------------------- */

    function test_delegateInteraction_Unauthorized() public withEnabledInteractionDelegation {
        bytes memory handleInteractionData = _getHandleInteractionData();

        InteractionDelegator.DelegatedInteraction[] memory delegatedInteraction =
            new InteractionDelegator.DelegatedInteraction[](1);
        delegatedInteraction[0] =
            InteractionDelegator.DelegatedInteraction(address(kernel), Interaction(productId, handleInteractionData));

        // Send it
        vm.expectRevert(Ownable.Unauthorized.selector);
        interactionDelegator.execute(delegatedInteraction);
    }

    function test_delegateInteractions_Unauthorized() public withEnabledInteractionDelegation {
        bytes memory handleInteractionData = _getHandleInteractionData();

        // Build the interaction to be sent
        Interaction[] memory interactions = new Interaction[](1);
        interactions[0] = Interaction(productId, handleInteractionData);

        // Wrap that in the right form
        InteractionDelegator.DelegatedBatchedInteraction[] memory delegatedInteraction =
            new InteractionDelegator.DelegatedBatchedInteraction[](1);
        delegatedInteraction[0] = InteractionDelegator.DelegatedBatchedInteraction(address(kernel), interactions);

        // Send it
        vm.expectRevert(Ownable.Unauthorized.selector);
        interactionDelegator.executeBatched(delegatedInteraction);
    }

    function test_delegateInteraction() public withEnabledInteractionDelegation {
        bytes memory handleInteractionData = _getHandleInteractionData();

        InteractionDelegator.DelegatedInteraction[] memory delegatedInteraction =
            new InteractionDelegator.DelegatedInteraction[](1);
        delegatedInteraction[0] =
            InteractionDelegator.DelegatedInteraction(address(kernel), Interaction(productId, handleInteractionData));

        // Send it
        vm.expectEmit(true, true, true, true, address(productInteraction));
        emit PressInteractionFacet.ArticleOpened(0, address(kernel));
        vm.prank(delegator);
        interactionDelegator.execute(delegatedInteraction);
    }

    function test_delegateInteractions() public withEnabledInteractionDelegation {
        bytes memory handleInteractionData = _getHandleInteractionData();

        // Build the interaction to be sent
        Interaction[] memory interactions = new Interaction[](1);
        interactions[0] = Interaction(productId, handleInteractionData);

        // Wrap that in the right form
        InteractionDelegator.DelegatedBatchedInteraction[] memory delegatedInteraction =
            new InteractionDelegator.DelegatedBatchedInteraction[](1);
        delegatedInteraction[0] = InteractionDelegator.DelegatedBatchedInteraction(address(kernel), interactions);

        // Send it
        vm.expectEmit(true, true, true, true, address(productInteraction));
        emit PressInteractionFacet.ArticleOpened(0, address(kernel));
        vm.prank(delegator);
        interactionDelegator.executeBatched(delegatedInteraction);
    }

    function test_delegateInteractions_compressed() public withEnabledInteractionDelegation {
        bytes memory handleInteractionData = _getHandleInteractionData();

        // Build the interaction to be sent
        Interaction[] memory interactions = new Interaction[](1);
        interactions[0] = Interaction(productId, handleInteractionData);

        // Wrap that in the right form
        InteractionDelegator.DelegatedBatchedInteraction[] memory delegatedInteraction =
            new InteractionDelegator.DelegatedBatchedInteraction[](1);
        delegatedInteraction[0] = InteractionDelegator.DelegatedBatchedInteraction(address(kernel), interactions);

        // Build the raw data to be sent
        bytes memory rawCalldata =
            abi.encodeWithSelector(InteractionDelegator.executeBatched.selector, delegatedInteraction);
        bytes memory compressedData = LibZip.cdCompress(rawCalldata);

        // Send it
        vm.expectEmit(true, true, true, true, address(productInteraction));
        emit PressInteractionFacet.ArticleOpened(0, address(kernel));
        vm.prank(delegator);
        (bool success,) = address(interactionDelegator).call(compressedData);
        assertTrue(success);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Delegation helpers                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Enable the interaction delegation session for the wallet
    modifier withEnabledInteractionDelegation() {
        vm.pauseGasMetering();
        // Enable single execution
        UserOperation memory op = buildUserOperation(
            abi.encodeWithSelector(
                IKernel.setExecution.selector,
                InteractionDelegatorAction.sendInteraction.selector,
                address(interactionDelegatorAction),
                address(interactionDelegatorValidator),
                uint48(0),
                uint48(0),
                bytes("")
            )
        );
        performUserOperationWithSig(op);
        // Enable batched execution
        op = buildUserOperation(
            abi.encodeWithSelector(
                IKernel.setExecution.selector,
                InteractionDelegatorAction.sendInteractions.selector,
                address(interactionDelegatorAction),
                address(interactionDelegatorValidator),
                uint48(0),
                uint48(0),
                bytes("")
            )
        );
        performUserOperationWithSig(op);
        vm.resumeGasMetering();
        _;
    }

    function _getHandleInteractionData() private returns (bytes memory handleInteractionData) {
        // Prepare the interaction data
        (bytes memory packedInteraction, bytes memory signature) = _prepareInteraction(
            DENOMINATOR_PRESS, PressInteractions.OPEN_ARTICLE, abi.encode(uint256(0)), address(kernel)
        );

        // Pack the interaction data
        vm.pauseGasMetering();
        handleInteractionData =
            abi.encodeWithSelector(ProductInteractionDiamond.handleInteraction.selector, packedInteraction, signature);
        vm.resumeGasMetering();
    }

    /* -------------------------------------------------------------------------- */
    /*                   Overrides from kernel + InteractionTest                  */
    /* -------------------------------------------------------------------------- */

    function test_ignore() external {}

    function _setExecutionDetail() internal virtual override {
        executionDetail.executor = address(new TestExecutor());
        executionSig = TestExecutor.doNothing.selector;
        executionDetail.validator = new TestValidator();
    }

    function getEnableData() internal view virtual override returns (bytes memory) {
        return "";
    }

    function getValidatorSignature(UserOperation memory) internal view virtual override returns (bytes memory) {
        return "";
    }

    function getOwners() internal view override returns (address[] memory) {
        address[] memory owners = new address[](1);
        owners[0] = owner;
        return owners;
    }

    function getInitializeData() internal view override returns (bytes memory) {
        return abi.encodeWithSelector(KernelStorage.initialize.selector, defaultValidator, abi.encodePacked(owner));
    }

    function signUserOp(UserOperation memory op) internal view override returns (bytes memory) {
        return abi.encodePacked(bytes4(0x00000000), entryPoint.signUserOpHash(vm, ownerKey, op));
    }

    function getWrongSignature(UserOperation memory op) internal view override returns (bytes memory) {
        return abi.encodePacked(bytes4(0x00000000), entryPoint.signUserOpHash(vm, ownerKey + 1, op));
    }

    function signHash(bytes32 hash) internal view override returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, ECDSA.toEthSignedMessageHash(hash));
        return abi.encodePacked(r, s, v);
    }

    function getWrongSignature(bytes32 hash) internal view override returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey + 1, ECDSA.toEthSignedMessageHash(hash));
        return abi.encodePacked(r, s, v);
    }

    function test_default_validator_enable() external override {
        UserOperation memory op = buildUserOperation(
            abi.encodeWithSelector(
                IKernel.execute.selector,
                address(defaultValidator),
                0,
                abi.encodeWithSelector(ECDSAValidator.enable.selector, abi.encodePacked(address(0xdeadbeef))),
                Operation.Call
            )
        );
        performUserOperationWithSig(op);
        (address owner_) = ECDSAValidator(address(defaultValidator)).ecdsaValidatorStorage(address(kernel));
        assertEq(owner_, address(0xdeadbeef), "owner should be 0xdeadbeef");
    }

    function test_default_validator_disable() external override {
        UserOperation memory op = buildUserOperation(
            abi.encodeWithSelector(
                IKernel.execute.selector,
                address(defaultValidator),
                0,
                abi.encodeWithSelector(ECDSAValidator.disable.selector, ""),
                Operation.Call
            )
        );
        performUserOperationWithSig(op);
        (address owner_) = ECDSAValidator(address(defaultValidator)).ecdsaValidatorStorage(address(kernel));
        assertEq(owner_, address(0), "owner should be 0");
    }

    function performSingleInteraction() internal override {
        vm.skip(true);
    }

    function getOutOfFacetScopeInteraction() internal override returns (bytes memory, bytes memory) {
        vm.skip(true);
    }
}
