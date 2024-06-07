// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

/// @dev Global type for a bytes4 olding an interaction type
type InteractionType is bytes4;

using InteractionTypeLib for InteractionType global;

using {interactionEq as ==} for InteractionType global;

function interactionEq(InteractionType self, InteractionType other) pure returns (bool isEquals) {
    assembly {
        isEquals := eq(self, other)
    }
}

/// @dev Set of helper functions for content types
library InteractionTypeLib {
    /// @dev Decode a packed interaction
    function deocdePackedInteraction(bytes calldata _data)
        internal
        pure
        returns (InteractionType interactionType, address user, bytes calldata remaining)
    {
        if (_data.length < 24) {
            remaining = _data;
            return (interactionType, user, remaining);
        }

        interactionType = InteractionType.wrap(bytes4(_data[0:4]));
        user = address(uint160(bytes20(_data[4:24])));
        remaining = _data[24:];
    }

    /// @dev Pack an interaction to be sent to a campaign
    function packInteractionForCampaign(InteractionType _interactionType, address user, bytes calldata _data)
        internal
        pure
        returns (bytes memory packedInteraction)
    {
        packedInteraction = abi.encodePacked(_interactionType, user, _data);
    }

    /// @dev Pack an interaction to be sent to a campaign
    function packInteractionForCampaign(InteractionType _interactionType, address user)
        internal
        pure
        returns (bytes memory packedInteraction)
    {
        packedInteraction = abi.encodePacked(_interactionType, user, "");
    }
}

/* -------------------------------------------------------------------------- */
/*                           Global interaction type                          */
/* -------------------------------------------------------------------------- */
InteractionType constant INTERACTION_WALLET_LINK = InteractionType.wrap(bytes4(0x00000001));

/* -------------------------------------------------------------------------- */
/*                       Press related interaction type                       */
/* -------------------------------------------------------------------------- */

library PressInteractions {
    /// @dev `bytes4(keccak256("frak.press.interaction.open_article"))`
    InteractionType constant OPEN_ARTICLE = InteractionType.wrap(0xc0a24ffb);

    /// @dev `bytes4(keccak256("frak.press.interaction.read_article"))`
    InteractionType constant READ_ARTICLE = InteractionType.wrap(0xd5bd0fbe);

    /// @dev `bytes4(keccak256("frak.press.interaction.referred"))`
    InteractionType constant REFERRED = InteractionType.wrap(0x3d1508ad);

    /// @dev Decode a referred interaction
    function decodeReferred(bytes calldata _data) internal pure returns (address referrer) {
        assembly {
            referrer := shr(96, calldataload(_data.offset))
        }
    }
}
