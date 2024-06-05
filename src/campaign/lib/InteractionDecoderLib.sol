// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionType} from "../../constants/InteractionType.sol";

/// @author @KONFeature
/// @title InteractionDecoderLib
/// @dev Library used to decode interactions
/// @custom:security-contact contact@frak.id
library InteractionDecoderLib {
    /// @dev Decode the interaction type from a bytes chain
    /// @dev Type is the first 4 bytes, the rest is the data
    function decodeInteraction(bytes calldata _data)
        internal
        pure
        returns (InteractionType interactionType, bytes calldata remaining)
    {
        if (_data.length < 4) {
            remaining = _data;
            return (interactionType, remaining);
        }

        interactionType = InteractionType.wrap(bytes4(_data[0:4]));
        remaining = _data[4:];
    }

    /* -------------------------------------------------------------------------- */
    /*                     Press related interaction decoding                     */
    /* -------------------------------------------------------------------------- */

    /// @dev Decode the data of a read article interaction
    function pressDecodeUseShareLink(bytes calldata _data) internal pure returns (address user) {
        assembly {
            user := shr(96, calldataload(_data.offset))
        }
    }
}
