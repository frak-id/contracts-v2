// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InvalidConfig} from "../constants/Errors.sol";

import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @author @KONFeature
/// @title PushPullModule
/// @notice Contract providing utilities to create push pull based module
/// @custom:security-contact contact@frak.id
abstract contract PushPullModule is ReentrancyGuard {
    using SafeTransferLib for address;

    /* -------------------------------------------------------------------------- */
    /*                                   Event's                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Emitted when a reward is added for a user
    event RewardAdded(address indexed user, address indexed token, uint256 amount);

    /// @dev Emitted when a reward is claimed by a user
    event RewardClaimed(address indexed user, address indexed token, uint256 amount);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Error when the contract doesn't have enouh token to distribute
    error NotEnoughToken();

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.module.push-pull')) - 1)
    bytes32 private constant _PUSH_PULL_MODULE_STORAGE_SLOT =
        0xb5d5f32fdcdcfca56d53b0b17de9c2bd793504ee1a7f7f226ef9e328f41bcfb5;

    /// @dev Storage per token
    struct PushPullStoragePerToken {
        /// @dev Total pending amount
        uint256 totalPending;
        /// @dev mapping of user to pending amount
        mapping(address wallet => uint256 amount) pendingAmount;
    }

    struct PushPullModuleStorage {
        /// @dev All the tokens handled data
        mapping(address token => PushPullStoragePerToken) tokens;
    }

    function _pushPullStorage() private pure returns (PushPullModuleStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _PUSH_PULL_MODULE_STORAGE_SLOT
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                             Add reward methods                             */
    /* -------------------------------------------------------------------------- */

    /// @notice Add a reward for the given `_user` with the given `_amount`
    function _pushReward(address _user, address _token, uint256 _amount) internal nonReentrant {
        // Get the given storage for the token
        PushPullStoragePerToken storage tokenStorage = _pushPullStorage().tokens[_token];

        // Compute the new pending total amount
        uint256 newTotalPending = tokenStorage.totalPending + _amount;

        // If greater than current balance, exit
        if (newTotalPending > _token.balanceOf(address(this))) {
            revert NotEnoughToken();
        }

        // Update the pending amount
        tokenStorage.pendingAmount[_user] += _amount;
        tokenStorage.totalPending = newTotalPending;

        // Emit the event
        emit RewardAdded(_user, _token, _amount);
    }

    struct Reward {
        address user;
        uint256 amount;
    }

    /// @notice Add multiple rewards for the given `_user` with the given `_amount`
    function _pushRewards(address _token, Reward[] memory _rewards) internal nonReentrant {
        // Get the given storage for the token
        PushPullStoragePerToken storage tokenStorage = _pushPullStorage().tokens[_token];

        // Get our control var
        uint256 newTotalPending = tokenStorage.totalPending;
        uint256 currentBalance = _token.balanceOf(address(this));

        // Iterate over each rewards
        for (uint256 i = 0; i < _rewards.length; i++) {
            Reward memory reward = _rewards[i];

            // Compute the new pending total amount
            newTotalPending += _rewards[i].amount;
            if (newTotalPending > currentBalance) {
                revert NotEnoughToken();
            }

            // Set the reward for the user
            tokenStorage.pendingAmount[reward.user] += reward.amount;

            // Emit the event
            emit RewardAdded(reward.user, _token, reward.amount);
        }

        // Update the total pending amount
        tokenStorage.totalPending = newTotalPending;
    }

    /* -------------------------------------------------------------------------- */
    /*                            Claim amount methods                            */
    /* -------------------------------------------------------------------------- */

    /// @notice Claim the pending amount for the given `_user`
    function pullReward(address _user, address _token) public nonReentrant {
        // Get the given storage for the token
        PushPullStoragePerToken storage tokenStorage = _pushPullStorage().tokens[_token];
        // Get the pending amount
        uint256 pendingAmount = tokenStorage.pendingAmount[_user];
        // Early exit if no pending amount
        if (pendingAmount == 0) {
            return;
        }

        // Reset the pending amount
        tokenStorage.pendingAmount[_user] = 0;
        tokenStorage.totalPending -= pendingAmount;

        // Transfer the pending amount
        _token.safeTransfer(_user, pendingAmount);

        // Emit the event
        emit RewardClaimed(_user, _token, pendingAmount);
    }

    /// @notice Claim the pending amount on every `_tokens` for the given `_user`
    function pullRewards(address _user, address[] calldata _tokens) public {
        for (uint256 i = 0; i < _tokens.length; i++) {
            pullReward(_user, _tokens[i]);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                            External view methods                           */
    /* -------------------------------------------------------------------------- */

    /// @notice Get the pending amount for the given `_user`
    function getPendingAmount(address _user, address _token) external view returns (uint256) {
        return _pushPullStorage().tokens[_token].pendingAmount[_user];
    }

    /// @notice Get the pending amount for the given `_user`
    function getTotalPending(address _token) external view returns (uint256) {
        return _pushPullStorage().tokens[_token].totalPending;
    }
}
