// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InvalidConfig} from "../constants/Errors.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";

/// @dev Config struct for a push pull module
struct PushPullConfig {
    /// @dev The address of the token used for the reward
    address token;
}

/// @author @KONFeature
/// @title PushPullModule
/// @notice Contract providing utilities to create push pull based module
/// @custom:security-contact contact@frak.id
abstract contract PushPullModule is ReentrancyGuard {
    using SafeTransferLib for address;

    /// @dev The token used to distribute the reward
    address private immutable _token;

    /* -------------------------------------------------------------------------- */
    /*                                   Event's                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Emitted when a reward is added for a user
    event RewardAdded(address indexed user, uint256 amount);

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

    /// @dev bytes32(uint256(keccak256('frak.module.push-pull')) - 1)
    bytes32 private constant _PUSH_PULL_MODULE_STORAGE_SLOT =
        0xb5d5f32fdcdcfca56d53b0b17de9c2bd793504ee1a7f7f226ef9e328f41bcfb5;

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

    /// @dev Constructor, set all our immutable fields
    constructor(PushPullConfig memory config) {
        if (config.token == address(0)) {
            revert InvalidConfig();
        }

        _token = config.token;
    }

    /* -------------------------------------------------------------------------- */
    /*                             Add reward methods                             */
    /* -------------------------------------------------------------------------- */

    /// @notice Add a reward for the given `_user` with the given `_amount`
    function _pushReward(address _user, uint256 _amount) internal nonReentrant {
        // Compute the new pending total amount
        uint256 newTotalPending = _pushPullStorage().totalPending + _amount;

        // If greater than current balance, exit
        if (newTotalPending > _token.balanceOf(address(this))) {
            revert NotEnoughToken();
        }

        // Update the pending amount
        _pushPullStorage().pendingAmount[_user] += _amount;
        _pushPullStorage().totalPending = newTotalPending;

        // Emit the event
        emit RewardAdded(_user, _amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Claim amount methods                            */
    /* -------------------------------------------------------------------------- */

    /// @notice Claim the pending amount for the given `msg.sender`
    function pullReward() public {
        pullReward(msg.sender);
    }

    /// @notice Claim the pending amount for the given `_user`
    function pullReward(address _user) public nonReentrant {
        // Get the pending amount
        uint256 pendingAmount = _pushPullStorage().pendingAmount[_user];
        // Early exit if no pending amount
        if (pendingAmount == 0) {
            return;
        }

        // Reset the pending amount
        _pushPullStorage().pendingAmount[_user] = 0;
        _pushPullStorage().totalPending -= pendingAmount;

        // Transfer the pending amount
        _token.safeTransfer(_user, pendingAmount);

        // Emit the event
        emit RewardClaimed(_user, pendingAmount);
    }

    /* -------------------------------------------------------------------------- */
    /*                            External view methods                           */
    /* -------------------------------------------------------------------------- */

    /// @notice Get the current contract config
    function getPushPullConfig() external view returns (PushPullConfig memory) {
        return PushPullConfig({token: _token});
    }

    /// @notice Get the pending amount for the given `_user`
    function getPendingAmount(address _user) external view returns (uint256) {
        return _pushPullStorage().pendingAmount[_user];
    }
}
