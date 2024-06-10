// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionType} from "../../constants/InteractionType.sol";

/// @title IInteractionFacet
/// @author @KONFeature
/// @notice Interface required for each interaction facet
/// @custom:security-contact contact@frak.id
interface IInteractionFacet {
    /// @dev Get the handled content type of this facet
    function contentTypeDenominator() external pure returns (uint8);

    /// @dev Check if this interaction facet handle signature assertion on it's own
    function handleSignature() external pure returns (bool);
}
