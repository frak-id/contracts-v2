// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

/// @dev Representing the activation period
struct ActivationPeriod {
    uint48 start;
    uint48 end;
}

/// @author @KONFeature
/// @title TimeLockedCampaign
/// @notice Simple lib to create a time locked campaign (with activation period (start + end))
abstract contract TimeLockedCampaign {
    /// @dev bytes32(uint256(keccak256('frak.campaign.activationPeriod')) - 1)
    function _activationPeriod() internal pure returns (ActivationPeriod storage storagePtr) {
        assembly {
            storagePtr.slot := 0xffbce109f8a876957e2d64e78d2e99f91f37a872cfc224245cd82b49d7114ea3
        }
    }

    /// @dev Set the activation period
    function _setActivationPeriod(ActivationPeriod memory _newPeriod) internal {
        ActivationPeriod storage activationPeriod = _activationPeriod();
        activationPeriod.start = _newPeriod.start;
        activationPeriod.end = _newPeriod.end;
    }
}
