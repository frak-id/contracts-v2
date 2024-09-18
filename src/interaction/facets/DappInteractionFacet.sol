// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {DappInteractions, InteractionType, InteractionTypeLib} from "../../constants/InteractionType.sol";
import {DENOMINATOR_DAPP} from "../../constants/ProductTypes.sol";
import {UPGRADE_ROLE} from "../../constants/Roles.sol";
import {MPT} from "../../utils/MPT.sol";
import {ProductInteractionStorageLib} from "../lib/ProductInteractionStorageLib.sol";
import {IInteractionFacet} from "./IInteractionFacet.sol";
import "forge-std/Console.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

/// @title DappFacet
/// @author @KONFeature
/// @notice Contract managing a user interacting with a dapp
/// @notice This is usefull wshen Dapps are built on other chains, and the interaction can be verified by storage modification (using a merklee patricia tree verification)
/// @custom:security-contact contact@frak.id
contract DappInteractionFacet is ProductInteractionStorageLib, IInteractionFacet, OwnableRoles {
    using InteractionTypeLib for bytes;

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    error UnknownContract();
    error CallFailed();
    error CallVerificationFailed();

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when a contract is registred
    event ContractRegistered(bytes4 indexed id, address contractAddress, bytes4 fnSelector);

    /// @dev Event emitted when a contract is un-registred
    event ContractUnRegistered(bytes4 indexed id);

    /// @dev Event when a storage at `slot` is updated to `value` on another contract
    event ProofStorageUpdated(address indexed smartContract, uint256 slot, uint256 value);

    /// @dev Event when a storage at `slot` is updated to `value` on another contract
    event CallableStorageUpdated(address indexed smartContract, uint256 value);

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.product.interaction.dapp')) - 1)
    bytes32 private constant _DAPP_INTERACTION_STORAGE_SLOT =
        0x43aba31b61ee7b53bc7d886cde0a33065b41ab8161e43a6ba307ffd2cd22dff4;

    /// @custom:storage-location erc7201:frak.product.interaction.dapp
    struct DappContractDefinition {
        address contractAddr;
        bytes4 storageFn;
    }

    struct DappFacetStorage {
        /// @dev Mapping of ids to address to contracts to follow
        mapping(bytes4 contractId => DappContractDefinition definition) contracts;
    }

    function _facetStorage() internal pure returns (DappFacetStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _DAPP_INTERACTION_STORAGE_SLOT
        }
    }

    constructor() {}

    /// @dev High level interaction router
    fallback(bytes calldata _data) external returns (bytes memory) {
        // Parse the interaction
        (InteractionType _action, bytes calldata _interactionData) = _data.unpackForFacet();

        if (_action == DappInteractions.CALLABLE_VERIFIABLE_STORAGE_UPDATE) {
            return _callableProofStorageUpdate(_interactionData);
        } else if (_action == DappInteractions.PROOF_VERIFIABLE_STORAGE_UPDATE) {
            return _handleProofStorageUpdate(_interactionData);
        }

        revert UnknownInteraction();
    }

    /// @dev Get the handled product type of this facet
    function productTypeDenominator() public pure override returns (uint8) {
        return DENOMINATOR_DAPP;
    }

    /* -------------------------------------------------------------------------- */
    /*                                Admin methods                               */
    /* -------------------------------------------------------------------------- */

    /// @dev Set a product contract address, will be used for update check and comparaison
    function setProductContract(address _contractAddress, bytes4 _storageCheckSelector)
        external
        onlyRoles(UPGRADE_ROLE)
    {
        bytes4 contractId = bytes4(keccak256(abi.encodePacked(_contractAddress, _storageCheckSelector)));
        _facetStorage().contracts[contractId] = DappContractDefinition(_contractAddress, _storageCheckSelector);
        emit ContractRegistered(contractId, _contractAddress, _storageCheckSelector);
    }

    /// @dev Set a product contract address, will be used for update check and comparaison
    function deleteProductContract(bytes4 id) external onlyRoles(UPGRADE_ROLE) {
        delete _facetStorage().contracts[id];
        emit ContractUnRegistered(id);
    }

    /* -------------------------------------------------------------------------- */
    /*                         Storage update via fn call                         */
    /* -------------------------------------------------------------------------- */

    struct CallableVerifableStorageUpdate {
        bytes4 contractId;
        uint256 storageValue;
    }

    /// @dev Verify that the storage of a contract was updated by perform a read call on the other contract, passing the current `msg.sender`
    function _callableProofStorageUpdate(bytes calldata _data) internal returns (bytes memory) {
        // Parse the input data
        CallableVerifableStorageUpdate calldata data;
        assembly {
            data := _data.offset
        }

        // Fetch the contract address
        DappContractDefinition storage definition = _facetStorage().contracts[data.contractId];
        address contractAddr = definition.contractAddr;
        if (contractAddr == address(0)) {
            revert UnknownContract();
        }

        // Perform the verification call
        (bool success, bytes memory result) =
            contractAddr.call(abi.encodeWithSelector(definition.storageFn, msg.sender));
        if (!success) {
            revert CallFailed();
        }

        // Verify the result
        if (abi.decode(result, (uint256)) != data.storageValue) {
            revert CallVerificationFailed();
        }

        // Emit the event
        emit CallableStorageUpdated(contractAddr, data.storageValue);

        // todo: return the right stuff for a campaign
        return DappInteractions.packVerifiedUpdateForCampaign(
            msg.sender, contractAddr, uint256(bytes32(definition.storageFn)), data.storageValue
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                          Sotrage update via proof                          */
    /* -------------------------------------------------------------------------- */

    struct ProofVerifableStorageUpdate {
        bytes4 contractId;
        bytes32 storageStateRoot;
        uint256 storageSlot;
        bytes[] storageProof;
    }

    /// @dev Handle the update of a storage value
    function _handleProofStorageUpdate(bytes calldata _data) internal returns (bytes memory) {
        // Parse the input data
        ProofVerifableStorageUpdate calldata data;
        assembly {
            data := _data.offset
        }

        // Fetch the contract address
        address contractAddr = _facetStorage().contracts[data.contractId].contractAddr;
        if (contractAddr == address(0)) {
            revert UnknownContract();
        }

        // TODO: Should also verify the state proof
        // Verify the storage proof
        uint256 value = _verifyAndGetStorageProof(data.storageStateRoot, data.storageSlot, data.storageProof);

        // Emit the event
        emit ProofStorageUpdated(contractAddr, data.storageSlot, value);

        // todo: return the right stuff for a campaign
        return DappInteractions.packVerifiedUpdateForCampaign(msg.sender, contractAddr, data.storageSlot, value);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Utils                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Verify the patricia merklee proof of a storage value, and return the founded value
    function _verifyAndGetStorageProof(bytes32 _storageStateRoot, uint256 _storageSlot, bytes[] calldata _storageProof)
        internal
        pure
        returns (uint256 value)
    {
        // Then, verify this storage root against the storage proof, and extract the value
        return MPT.verifyAndGetStorageSlot(_storageStateRoot, _storageSlot, _storageProof);
    }
}
