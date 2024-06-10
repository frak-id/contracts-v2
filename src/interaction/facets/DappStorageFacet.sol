// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {DENOMINATOR_DAPP_STORAGE} from "../../constants/ContentTypes.sol";
import {DappStorageInteractions, InteractionType, InteractionTypeLib} from "../../constants/InteractionType.sol";

import {MPT} from "../../utils/MPT.sol";
import {ContentInteractionStorageLib} from "../lib/ContentInteractionStorageLib.sol";
import {IInteractionFacet} from "./IInteractionFacet.sol";

/// @title DappStorageFacet
/// @author @KONFeature
/// @notice Contract managing a user interacting with a dapp smart contract storage
/// @notice This is usefull wshen Dapps are built on other chains, and the interaction can be verified by storage modification (using a merklee patricia tree verification)
/// @custom:security-contact contact@frak.id
contract ContractStorageFacet is ContentInteractionStorageLib, IInteractionFacet {
    using InteractionTypeLib for bytes;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event when a storage at `slot` is updated to `value` on another contract
    event StorageUpdated(uint256 indexed slot, uint256 value);

    constructor() {}

    /// @dev High level interaction router
    fallback(bytes calldata _data) external returns (bytes memory) {
        // Parse the interaction
        (InteractionType _action, bytes calldata _interactionData) = _data.unpackForFacet();

        if (_action == DappStorageInteractions.UPDATE) {
            return _handleUpdateStorage(_interactionData);
        }

        revert UnknownInteraction();
    }

    /// @dev Get the handled content type of this facet
    function contentTypeDenominator() public pure override returns (uint8) {
        return DENOMINATOR_DAPP_STORAGE;
    }

    function handleSignature() public pure override returns (bool) {
        return true;
    }

    /* -------------------------------------------------------------------------- */
    /*                               Storage update                               */
    /* -------------------------------------------------------------------------- */

    struct StorageUpdateData {
        uint256 storageSlot;
        bytes[] proof;
    }

    /// @dev Handle the update of a storage value
    function _handleUpdateStorage(bytes calldata _data) internal returns (bytes memory) {
        // Parse the input data
        StorageUpdateData calldata data;
        assembly {
            data := _data.offset
        }

        // Get the storage root
        bytes32 _root = keccak256("test");

        // Verify the storage proof
        // todo: also assert storage slot mnatch a contract
        // todo: contract should be set by the owner
        uint256 value = _verifyAndGetStorageProof(_root, data.storageSlot, data.proof);

        // Emit the event
        emit StorageUpdated(data.storageSlot, value);

        // todo: return the right stuff for a campaign
        return "";
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Utils                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Verify the patricia merklee proof of a storage value, and return the founded value
    function _verifyAndGetStorageProof(bytes32 _root, uint256 _storageSlot, bytes[] calldata _proof)
        internal
        pure
        returns (uint256 value)
    {
        return MPT.verifyAndGetStorageSlot(_root, _storageSlot, _proof);
    }
}
