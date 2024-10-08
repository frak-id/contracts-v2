// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @dev Reward struct to sent to a user
struct Reward {
    address user;
    uint256 amount;
}

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
    event RewardAdded(address indexed user, address emitter, uint256 amount);

    /// @dev Emitted when a reward is claimed by a user
    event RewardClaimed(address indexed user, uint256 amount);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Error when the contract doesn't have enouh token to distribute
    error NotEnoughToken();

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev The token that will be used for the rewards
    address internal immutable TOKEN;

    /// @dev bytes32(uint256(keccak256('frak.module.push-pull')) - 1)
    bytes32 private constant _PUSH_PULL_MODULE_STORAGE_SLOT =
        0xb5d5f32fdcdcfca56d53b0b17de9c2bd793504ee1a7f7f226ef9e328f41bcfb5;

    /// @custom:storage-location erc7201:frak.module.push-pull
    struct PushPullModuleStorage {
        /// @dev Total pending amount
        uint256 totalPending;
        /// @dev mapping of user to pending amount
        mapping(address wallet => uint256 amount) pendingAmount;
    }

    function _pushPullStorage() private pure returns (PushPullModuleStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _PUSH_PULL_MODULE_STORAGE_SLOT
        }
    }

    constructor(address _token) {
        TOKEN = _token;
    }

    /* -------------------------------------------------------------------------- */
    /*                             Add reward methods                             */
    /* -------------------------------------------------------------------------- */

    /// @notice Add a reward for the given `_user` with the given `_amount`
    function _pushReward(address _user, uint256 _amount) internal nonReentrant {
        // Get the given storage for the token
        PushPullModuleStorage storage tokenStorage = _pushPullStorage();

        // Compute the new pending total amount
        uint256 newTotalPending = tokenStorage.totalPending + _amount;

        // If greater than current balance, exit
        if (newTotalPending > TOKEN.balanceOf(address(this))) {
            revert NotEnoughToken();
        }

        // Update the pending amount
        tokenStorage.pendingAmount[_user] += _amount;
        tokenStorage.totalPending = newTotalPending;

        // Emit the event
        emit RewardAdded(_user, msg.sender, _amount);
    }

    /// @notice Add multiple rewards for the given `_user` with the given `_amount` via calldata
    function _pushRewards(Reward[] calldata _rewards) internal nonReentrant {
        // Get the given storage for the token
        PushPullModuleStorage storage tokenStorage = _pushPullStorage();

        // Get our control var
        uint256 newTotalPending = tokenStorage.totalPending;
        uint256 currentBalance = TOKEN.balanceOf(address(this));

        // Iterate over each rewards
        for (uint256 i = 0; i < _rewards.length; i++) {
            Reward memory reward = _rewards[i];

            // Compute the new pending total amount
            newTotalPending += reward.amount;
            if (newTotalPending > currentBalance) {
                revert NotEnoughToken();
            }

            // Set the reward for the user
            tokenStorage.pendingAmount[reward.user] += reward.amount;

            // Emit the event
            emit RewardAdded(reward.user, msg.sender, reward.amount);
        }

        // Update the total pending amount
        tokenStorage.totalPending = newTotalPending;
    }

    /* -------------------------------------------------------------------------- */
    /*                            Claim amount methods                            */
    /* -------------------------------------------------------------------------- */

    /// @notice Claim the pending amount for the given `_user`
    function pullReward(address _user) public nonReentrant {
        // Get the given storage for the token
        PushPullModuleStorage storage tokenStorage = _pushPullStorage();
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
        TOKEN.safeTransfer(_user, pendingAmount);

        // Emit the event
        emit RewardClaimed(_user, pendingAmount);
    }

    /* -------------------------------------------------------------------------- */
    /*                            External view methods                           */
    /* -------------------------------------------------------------------------- */

    /// @notice Get the pending amount for the given `_user`
    function getPendingAmount(address _user) external view returns (uint256) {
        return _pushPullStorage().pendingAmount[_user];
    }

    /// @notice Get the total pending amount
    function getTotalPending() public view returns (uint256) {
        return _pushPullStorage().totalPending;
    }

    /// @notice Get the token linked to this push pull reward
    function getToken() public view returns (address) {
        return TOKEN;
    }
}
