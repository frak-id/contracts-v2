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
    /* -------------------------------------------------------------------------- */
    /*                         Global packing / unpacking                         */
    /* -------------------------------------------------------------------------- */

    /// @dev Unpack an interaction from the manager
    function unpackForManager(bytes calldata _data)
        internal
        pure
        returns (uint8 contentTypeDenominator, bytes calldata facetData)
    {
        unchecked {
            if (_data.length < 5) {
                facetData = _data;
                return (contentTypeDenominator, facetData);
            }

            contentTypeDenominator = uint8(_data[0]);
            // Facet data contain everything after the content type denominator
            facetData = _data[1:];
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                       Interaction packing / unpacking                      */
    /* -------------------------------------------------------------------------- */

    /// @dev Unpack an interaction for a facet
    function unpackForFacet(bytes calldata _data)
        internal
        pure
        returns (InteractionType interactionType, bytes calldata data)
    {
        unchecked {
            if (_data.length < 4) {
                data = _data;
                return (interactionType, data);
            }

            interactionType = InteractionType.wrap(bytes4(_data[0:4]));
            data = _data[4:];
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                        Campaign packing / unpacking                        */
    /* -------------------------------------------------------------------------- */

    /// @dev Decode a packed interaction
    function unpackForCampaign(bytes calldata _data)
        internal
        pure
        returns (InteractionType interactionType, address user, bytes calldata remaining)
    {
        unchecked {
            if (_data.length < 24) {
                remaining = _data;
                return (interactionType, user, remaining);
            }

            interactionType = InteractionType.wrap(bytes4(_data[0:4]));
            user = address(uint160(bytes20(_data[4:24])));
            remaining = _data[24:];
        }
    }

    /// @dev Pack an interaction to be sent to a campaign
    function packForCampaign(InteractionType _interactionType, address user, bytes calldata _data)
        internal
        pure
        returns (bytes memory packedInteraction)
    {
        packedInteraction = abi.encodePacked(_interactionType, user, _data);
    }

    /// @dev Pack an interaction to be sent to a campaign
    function packForCampaign(InteractionType _interactionType, address user)
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

library DappInteractions {
    /// @dev `bytes4(keccak256("frak.dapp.interaction.proof_verifiable_storage_update"))`
    InteractionType constant PROOF_VERIFIABLE_STORAGE_UPDATE = InteractionType.wrap(0x2ab2aeef);

    /// @dev `bytes4(keccak256("frak.dapp.interaction.callable_verifiable_storage_update"))`
    InteractionType constant CALLABLE_VERIFIABLE_STORAGE_UPDATE = InteractionType.wrap(0xa07da986);

    /// @dev `bytes4(keccak256("frak.dapp.interaction.storage_update_confirmed"))`
    InteractionType constant STORAGE_UPDATE_CONFIRMED = InteractionType.wrap(0xb2e5ce88);

    /// @dev Pack a verified update interaction for a campaign
    function packVerifiedUpdateForCampaign(
        address _user,
        address _smartContract,
        uint256 _storageSlotOrFnSelector,
        uint256 _storageValue
    ) internal pure returns (bytes memory packedInteraction) {
        packedInteraction =
            abi.encodePacked(STORAGE_UPDATE_CONFIRMED, _user, _smartContract, _storageSlotOrFnSelector, _storageValue);
    }
}

library PressInteractions {
    /// @dev `bytes4(keccak256("frak.press.interaction.open_article"))`
    InteractionType constant OPEN_ARTICLE = InteractionType.wrap(0xc0a24ffb);

    /// @dev `bytes4(keccak256("frak.press.interaction.read_article"))`
    InteractionType constant READ_ARTICLE = InteractionType.wrap(0xd5bd0fbe);
}

library ReferralInteractions {
    /// @dev `bytes4(keccak256("frak.referral.interaction.referred"))`
    InteractionType constant REFERRED = InteractionType.wrap(0x010cc3b9);

    /// @dev `bytes4(keccak256("frak.referral.interaction.link_creation"))`
    InteractionType constant REFERRAL_LINK_CREATION = InteractionType.wrap(0xb2c0f17c);
}
