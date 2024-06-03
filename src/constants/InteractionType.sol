// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

/// @dev Global type for a bytes8 olding an interaction type
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
    // TODO: some stuff here

    function fromUint(uint32 _value) internal pure returns (InteractionType interactionType) {
        assembly {
            interactionType := _value
        }
    }
}

/* -------------------------------------------------------------------------- */
/*                           Global interaction type                          */
/* -------------------------------------------------------------------------- */
InteractionType constant INTERACTION_WALLET_LINK = InteractionType.wrap(bytes4(0x00000001));

/* -------------------------------------------------------------------------- */
/*                       Press related interaction type                       */
/* -------------------------------------------------------------------------- */

InteractionType constant INTERACTION_PRESS_OPEN_ARTICLE = InteractionType.wrap(bytes4(0x00000002));
InteractionType constant INTERACTION_PRESS_READ_ARTICLE = InteractionType.wrap(bytes4(0x00000003));
InteractionType constant INTERACTION_PRESS_CREATE_SHARE_LINK = InteractionType.wrap(bytes4(0x00000004));
InteractionType constant INTERACTION_PRESS_USED_SHARE_LINK = InteractionType.wrap(bytes4(0x00000005));
