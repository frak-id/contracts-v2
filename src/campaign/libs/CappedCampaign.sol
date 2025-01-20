// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

/// @dev Representing the current cap state
/// @custom:storage-location erc7201:frak.campaign.capState
struct CapState {
    uint48 startTimestamp;
    uint208 distributedAmount;
}

/// @dev Representing the cap config
struct CapConfig {
    // Distribution cap period, in seconds
    uint48 period;
    // Distribution cap amount
    uint208 amount;
}

/// @author @KONFeature
/// @title CappedCampaign
/// @notice Simple lib to create capped campaign
/// @custom:security-contact contact@frak.id
abstract contract CappedCampaign {
    /// @dev Event when the daily distribution cap is reset
    event DistributionCapReset(uint48 previousTimestamp, uint256 distributedAmount);

    /// @dev Event when the distribution cap is reached
    error DistributionCapReached();

    /// @dev bytes32(uint256(keccak256('frak.campaign.capState')) - 1)
    function _capState() internal pure returns (CapState storage storagePtr) {
        assembly {
            storagePtr.slot := 0xcba14a58dd359829fa2f6d697e8186fab92915f9d9659ed068a3007b5d062519
        }
    }

    /// @dev bytes32(uint256(keccak256('frak.campaign.capConfig')) - 1)
    function _capConfig() internal pure returns (CapConfig storage storagePtr) {
        assembly {
            storagePtr.slot := 0x3718d87d99e652b99c55db0a58e20d023ceff4ae105b7e34629e4a7d4094a409
        }
    }

    /// @dev Update the distribution cap
    /// @dev  And reset it if needed
    function _updateDistributionCap(uint256 _distributedAmount) internal {
        // If we have no cap, exit
        CapConfig storage capConfig = _capConfig();
        if (capConfig.amount == 0) {
            return;
        }

        CapState memory capReadOnly = _capState();

        unchecked {
            // Cap reset case
            if (block.timestamp > capReadOnly.startTimestamp + capConfig.period) {
                emit DistributionCapReset(capReadOnly.startTimestamp, capReadOnly.distributedAmount);

                _capState().startTimestamp = uint48(block.timestamp);
                _capState().distributedAmount = uint208(_distributedAmount);

                return;
            }
            // Check if we can distribute the reward
            if (capReadOnly.distributedAmount + _distributedAmount > capConfig.amount) {
                revert DistributionCapReached();
            }
            _capState().distributedAmount += uint208(_distributedAmount);
        }
    }

    /// @dev Set the cap config
    function _setCapConfig(CapConfig memory _config) internal {
        CapConfig storage cap = _capConfig();
        cap.period = _config.period;
        cap.amount = _config.amount;
    }
}
