// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ProductInteractionDiamond} from "../interaction/ProductInteractionDiamond.sol";
import {ProductInteractionManager} from "../interaction/ProductInteractionManager.sol";

/// @author @KONFeature
/// @title ICampaignFactory
/// @notice Interfaces for campaign factory
/// @custom:security-contact contact@frak.id
interface ICampaignFactory {
    /// @dev Entry point to create a new campaign for the given `_identifier` with the given `_initData`
    function createCampaign(ProductInteractionDiamond _interaction, bytes4 _identifier, bytes calldata _initData)
        external
        returns (address);
}
