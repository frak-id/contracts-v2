// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ContentInteractionDiamond} from "../interaction/ContentInteractionDiamond.sol";
import {ContentInteractionManager} from "../interaction/ContentInteractionManager.sol";

/// @author @KONFeature
/// @title ICampaignFactory
/// @notice Interfaces for campaign factory
/// @custom:security-contact contact@frak.id
interface ICampaignFactory {
    /// @dev Entry point to create a new campaign for the given `_identifier` with the given `_initData`
    function createCampaign(
        ContentInteractionDiamond _interaction,
        address _owner,
        bytes4 _identifier,
        bytes calldata _initData
    ) external returns (address);
}
