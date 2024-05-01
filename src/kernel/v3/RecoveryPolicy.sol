// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {PolicyBase} from "kernel/sdk/moduleBase/PolicyBase.sol";
import {ExecLib, ExecMode, CALLTYPE_DELEGATECALL, CallType, ExecType} from "kernel/utils/ExecLib.sol";
import {IERC7579Account, PackedUserOperation} from "kernel/interfaces/IERC7579Account.sol";

/// @author @KONFeature
/// @title RecoveryPolicy
/// @notice A smart contract used to allow an ecdsa to perform the recovery for a smart account
contract RecoveryPolicy is PolicyBase {
    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Error when a non smart account is trying to execute another method than `execute` from the smart account
    error OnlySmartAccountExecuteAllowed();

    /// @dev Error when a non smart account is trying to execute another method than `execute` from the smart account
    error OnlyDelegateCallTypeAllowed();

    /// @dev Error when the polic isn't found
    error UnknownPolicy();

    /// @dev Error when the call violates the recover rule
    error CallViolatesRecoverRule();

    /// @dev Error when a policy would be a duplicated one
    error DuplicatePolicy();

    /// @dev error throwned when a signature check is performed and not supported
    error SignatureCheckNotSupported();

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.policy.recover')) - 1)
    bytes32 private constant _RECOVER_POLICY_STORAGE_SLOT =
        0xded78916531cbd81a5e00a4484a9b7b7c881901b3a7720efbca65765470834ec;

    /// @dev Per wallet mapping of the recover policy
    struct RecoverPolicyDetail {
        /// @dev The address of the recover contract
        address recoverContract;
        /// @dev The method selector to call on the recover contract
        bytes4 recoverSelector;
        /// @dev The timestamp at which this policy will be active
        uint48 activeAt;
    }

    struct RecoverPolicyStorage {
        /// @dev Mapping of wallet, to policy id, to details
        mapping(address wallet => mapping(bytes32 id => RecoverPolicyDetail detail)) policies;
        /// @dev Mapping of wallet to the count of used policies
        mapping(address wallet => uint256) usedPolicies;
    }

    function _recoverPolicyStorage() private pure returns (RecoverPolicyStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _RECOVER_POLICY_STORAGE_SLOT
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                               Initialisation                               */
    /* -------------------------------------------------------------------------- */

    /// @dev Hook for when a policy installation is asked
    function _policyOninstall(bytes32 _id, bytes calldata _data) internal override {
        // Get the right storage ptr
        RecoverPolicyDetail storage detail = _getPolicyForCaller(_id);

        // If already got some data in it, revert
        if (detail.recoverContract != address(0)) {
            revert DuplicatePolicy();
        }

        // Parse the data
        RecoverPolicyDetail memory callDetail = abi.decode(_data, (RecoverPolicyDetail));

        // Set the data
        detail.recoverContract = callDetail.recoverContract;
        detail.recoverSelector = callDetail.recoverSelector;
        detail.activeAt = callDetail.activeAt;

        // And increase the counter
        _recoverPolicyStorage().usedPolicies[msg.sender]++;
    }

    /// @dev Hook for when a policy uninstallation is asked
    function _policyOnUninstall(bytes32 _id, bytes calldata) internal override {
        // Find the policy detail
        RecoverPolicyDetail storage detail = _getPolicyForCaller(_id);
        // Delete it
        delete detail.recoverContract;
        delete detail.recoverSelector;
        delete detail.activeAt;
        // And decrease the counter
        _recoverPolicyStorage().usedPolicies[msg.sender]--;
    }

    /// @dev Check if a policy is enabled or not for a given _wallet
    function isInitialized(address _wallet) external view override returns (bool) {
        return _recoverPolicyStorage().usedPolicies[_wallet] > 0;
    }

    /* -------------------------------------------------------------------------- */
    /*                                Policy checks                               */
    /* -------------------------------------------------------------------------- */

    /// @dev Check the validity of a user operation for this policy
    function checkUserOpPolicy(bytes32 _id, PackedUserOperation calldata _userOp)
        external
        payable
        override
        returns (uint256)
    {
        // Get the policy and ensure it exist
        RecoverPolicyDetail storage detail = _getPolicyForCaller(_id);
        if (detail.recoverContract == address(0)) {
            revert UnknownPolicy();
        }

        // Ensure the call is about a account execution
        bytes calldata _opCalldata = _userOp.callData;
        if (bytes4(_opCalldata[0:4]) != IERC7579Account.execute.selector) {
            revert OnlySmartAccountExecuteAllowed();
        }

        // Extract execution mode from the calldata
        ExecMode mode = ExecMode.wrap(bytes32(_opCalldata[4:36]));
        (CallType callType,,,) = ExecLib.decode(mode);

        // Ensure the call is a delegate call
        if (callType != CALLTYPE_DELEGATECALL) {
            revert OnlyDelegateCallTypeAllowed();
        }

        // Extract the execution call data (skipping the mode)
        bytes calldata executionCallData = _opCalldata;
        assembly {
            executionCallData.offset :=
                add(add(executionCallData.offset, 0x24), calldataload(add(executionCallData.offset, 0x24)))
            executionCallData.length := calldataload(sub(executionCallData.offset, 0x20))
        }
        // Decode the execution call data
        (address target,, bytes calldata callData) = ExecLib.decodeSingle(executionCallData);

        // Ensure address and fn selector match the policy
        if (
            target != detail.recoverContract || bytes4(callData[0:4]) != detail.recoverSelector
                || detail.activeAt > block.timestamp
        ) {
            revert CallViolatesRecoverRule();
        }

        // 0 -> Allowed, 1 -> Not allowed
        return 0;
    }

    /// @dev Check if the signature policy is allowed
    /// @dev Will always fail, signature policy disabled for recovery!
    function checkSignaturePolicy(bytes32, address, bytes32, bytes calldata) external pure override returns (uint256) {
        revert SignatureCheckNotSupported();
    }

    /* -------------------------------------------------------------------------- */
    /*                               Helper methods                               */
    /* -------------------------------------------------------------------------- */

    /// @dev Small helper to fetch the policy for the caller with the given _id
    function _getPolicyForCaller(bytes32 _id) private view returns (RecoverPolicyDetail storage detail) {
        return _recoverPolicyStorage().policies[msg.sender][_id];
    }

    /// @dev Get the policy for a given wallet and id
    function getPolicyForWallet(address _wallet, bytes32 _id) external view returns (RecoverPolicyDetail memory) {
        return _recoverPolicyStorage().policies[_wallet][_id];
    }

    /// @dev Get the policy for a given wallet and id
    function getPolicyCountForWallet(address _wallet) external view returns (uint256) {
        return _recoverPolicyStorage().usedPolicies[_wallet];
    }
}
