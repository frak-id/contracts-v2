// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {DENOMINATOR_DAPP_STORAGE} from "../../constants/ContentTypes.sol";
import {DappStorageInteractions, InteractionType, InteractionTypeLib} from "../../constants/InteractionType.sol";
import {UPGRADE_ROLE} from "../../constants/Roles.sol";
import {MPT} from "../../utils/MPT.sol";
import {ContentInteractionStorageLib} from "../lib/ContentInteractionStorageLib.sol";
import {IInteractionFacet} from "./IInteractionFacet.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";

/// @title DappStorageFacet
/// @author @KONFeature
/// @notice Contract managing a user interacting with a dapp smart contract storage
/// @notice This is usefull wshen Dapps are built on other chains, and the interaction can be verified by storage modification (using a merklee patricia tree verification)
/// @custom:security-contact contact@frak.id
contract DappStorageFacet is ContentInteractionStorageLib, IInteractionFacet, OwnableRoles {
    using InteractionTypeLib for bytes;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event when a storage at `slot` is updated to `value` on another contract
    event StorageUpdated(uint256 indexed slot, uint256 value);

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.content.interaction.dapp_storage')) - 1)
    bytes32 private constant _DAPP_STORAGE_INTERACTION_STORAGE_SLOT =
        0x34cc5f3478b36ca0e64c484dff95b60f2eb59fcd3d0e55b4a0a7d5c1e8329cfa;

    struct DappStorageFacetStorage {
        /// @dev Mapping of ids to address to contracts to follow
        mapping(uint256 contractId => address contractAddress) contracts;
    }

    function _facetStorage() internal pure returns (DappStorageFacetStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _DAPP_STORAGE_INTERACTION_STORAGE_SLOT
        }
    }

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

    /* -------------------------------------------------------------------------- */
    /*                                Admin methods                               */
    /* -------------------------------------------------------------------------- */

    /// @dev Set a content contract address, will be used for update check and comparaison
    function setContentContract(uint256 _contractId, address _contractAddress) external onlyRoles(UPGRADE_ROLE) {
        _facetStorage().contracts[_contractId] = _contractAddress;
    }

    /* -------------------------------------------------------------------------- */
    /*                               Storage update                               */
    /* -------------------------------------------------------------------------- */

    struct StorageUpdateData {
        uint256 contractId;
        bytes32 stateRoot;
        uint256 storageSlot;
        bytes[] stateProof;
        bytes[] storageProof;
    }

    /// @dev Handle the update of a storage value
    function _handleUpdateStorage(bytes calldata _data) internal returns (bytes memory) {
        // Parse the input data
        StorageUpdateData calldata data;
        assembly {
            data := _data.offset
        }

        // Fetch the contract address
        address contractAddr = _facetStorage().contracts[data.contractId];

        // Verify the storage proof
        // todo: also assert storage slot mnatch a contract
        // todo: contract should be set by the owner
        uint256 value = _verifyAndGetStorageProof(
            contractAddr, data.stateRoot, data.storageSlot, data.stateProof, data.storageProof
        );

        // Emit the event
        emit StorageUpdated(data.storageSlot, value);

        // todo: return the right stuff for a campaign
        return "";
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Utils                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Verify the patricia merklee proof of a storage value, and return the founded value
    function _verifyAndGetStorageProof(
        address _contract,
        bytes32 _root,
        uint256 _storageSlot,
        bytes[] calldata _stateProof,
        bytes[] calldata _storageProof
    ) internal pure returns (uint256 value) {
        // Verify the state proof, and extract the storage root from it
        bytes32 storageRoot = MPT.getAccountStorageRoot(_contract, _root, _stateProof);
        // Then, verify this storage root against the storage proof, and extract the value
        return MPT.verifyAndGetStorageSlot(storageRoot, _storageSlot, _storageProof);
    }
}

/*

 EIP1186AccountProofResponse { 
    address: 0x87f5f41f6535ec4e6bb8b303585f0a2a32db708e, 
    balance: 0x0_U256, 
    code_hash: 0x795221c80f59440880c9e1f5798646e59a73baee7869bff64eed9bf7445e2ffc, 
    nonce: 0x0000000000000001_U64, 
    storage_hash: 0x79f94a9e0de4f107c4122a3cee2770282536f4241936e2b4dffa17261077214a, 
    account_proof: [
        0xf90211a0380bd36a998e9bb619a386f9e2aad1daa52199d51d2b96763c3e63cbc59a0a8da09612a7d9b5c8f1227e7f87f11789c2b3d6600572446160501a6c44b1492a9afda09ad0696d3c0769a6af28237b2e914fe516e688b02ae1d7e7e77d9a02db252f0ba0c3855dbe86c7cdcbfbf67a524b58a6ad36d09357b3749649aa7706a02fa777d4a0ddd352c0341c204a1bc838bfb2a176f6d81d5e7dedc959d9ad55e765c57b8380a0147f051603dab741a46c77432ce6db77930edb962694939a83297a59a5879b5da02f8c70cc89c9a4ef9d0a48492787f90af5de74aba0fe1b4599f649acfac7e9e0a01c9e74d92480dc83d06aec67c146a04632c512958e1cf54311e4592ef6c579b8a013d0a10856e5c42c1be87cac1d897d981204fdea50172c1715351ce783a1959fa03ba83d6bd9dad0978fee76a16237a98b9a5069e306be2e3f4b6ccbc287942b0ea0880c276078c33807143943899db0b39987114141d07474f2ed760b8f9eaea407a0a833c04f9bff7990a8d0361024add5a01f085f96a8689b0d4511405f770e3005a064997e9f5be9388122c976447617c8a3bcabfcc2da086219853dde47d8096907a05fe5743ffbee4bdd7563db6f6f9870b4273e3a7fb6cad3a9e2274e569c610622a0917c6ae90a3d779cdc4f1a74d175cf74035f54d36ae710a7207fe6e7fec2651ca066080c88255687914bea0ef8381fd2d556b44340893018cbff18a3224f9f681280, 
        0xf90211a0967f0d8bcb4b29ff4e38d2c19296c06c430b296aaf73cccefb19c23ff9ee3091a01b5e7324f58ac29a3e856449ddd94fd901392295e6ae5e309f21cea128831767a0d37ae14838c018d1b41505ce3f82d85fc143443583d78636f261572f08b2b645a01de92a6b42cfdd4a1ef4b84c40b5f01cf69371dd9fcaa66b51a65153d5f98a8ea0f7098e303074761be50b760d9395fdf9b36cba7323f723c240e2506abd8701e9a09f397b5001cc623a87dd06bb4eeb72e81ae697063f5fdf714ca2157b65c28678a027cb5ab2a361ae7e741f5661db7c69c967e2d96c875019c8d07c06e84fcc6b62a07d11c8c150e2368fc1f185a0884347ac985d79e195684a470892328122d72460a07cad76e6e5b38617aaf5dd72e75b2a71e90fb6b48d7a21835086d02fd30d7cf7a0dde239aae6148878be5477b09c7a3d24203a2252ae6213fe4583f8d0ed3d6cd8a0b15d073931a4394bdc2b49ad0d8b599671917023bbbafb955ffdd8118b5cab73a0e0b307948b01b901ac66974f1bd68a4ace01eecbb8f7f8d7f6da5dcd97361993a0fa22bc7713f465880002eed7f15668884af32efa52cfcd6254c65950f8e80d09a0829153dd5a3328dbf0dabf7bed96583e03a726f23ee2da4a6d001c9d2383fae1a050bd138bc74819c403c8f16df9a0ae5efd6a67098765a8fa01febd79737fa7caa0a7aae820c90bdab38821892c7eac671fe56ea570196a2e6fc431c70e14ca6bd980, 
        0xf901d1a05ee7ba479cce0bba2c888a964f9d2ffd4f65fd5d7363a31811a5fa9b7c61c463a0bc8bd3ab6487f652e3f410ffa8306a3eb03a602bc9868665e7f8d95fd844f14fa0447f5a3ecd1eb11bc95c580553553ada5db62a1b3d9a021ee0319e4cef6f291ea09a5be658dc7e0e34060ff37fefe8afea7e7b5980207ba0bef5fea9788eb76878a081aed51f9223f423ec34e411878815a2930ddafcd528141f9fe3f1a7dd51db59a0d950c168ff577a6ff99ddce9069987f14cb1b9305147d2c5cc924514c89a460ea05588923977ef714a228124ae50dc700bedae6857eef53a6defc05416ad5416a3a0b8f95d30a1c6014de5f330392c2fad2e5db1c9e0ecca02c1ddc85d6445cd43d880a0e9cdab7eeee6b313aac3d9c4cf43d0c6340cc06e1fdf9726e3c0202ed7bde38ca0fdc45dc4e706fed196124657dab67afb0e50fbc83b5cbb1555c917ecfc68f0c6a09f39f701d79af88391144774653345ade3ad0f9ef8981f004522c20165ddfde080a0d13a8139bfdd0f42e9e87a1b80da1a18d4cf98a55792c00964702996684f7231a05bdcc0ca6c4e4b64bfe6e8d5e3150c23d9e9a746499dc567eb71dd4e97d81ed5a0bb7f241530d47f9ac33725f12b0015feb3536fcad277314e1fc653d2045ad44880, 
        0xf8689f3dceca81d3459c592d7fcbdc308d8c22c99474c87ad4d8d9e6e4dd2a1fe63eb846f8440180a079f94a9e0de4f107c4122a3cee2770282536f4241936e2b4dffa17261077214aa0795221c80f59440880c9e1f5798646e59a73baee7869bff64eed9bf7445e2ffc
    ], 
    storage_proof: [
        EIP1186StorageProof { 
            key: JsonStorageKey(0x483612feee598e08d8bf3aa226735aff45a76cf706b64b2b8952a30e01cbe484), 
            value: 0x0000000000000000000000000000000000000000000000000000000000000001_U256, 
            proof: [
                0xf90151a03f6c1dcc9bf1e937acb30c66c23822b7c3a274aeac57b012baecd6aa01545d7da0a1532f2cf67d0ff7ad7e0be264d2d9975195102febaa8ff4f8a2aa9ac95e4d84a0a79dbb34108cd4a27a5119655fe18bd7e1d35990fd80a00caf3741598098722f8080a0e49730ed68aef37c197fdde6fe2315a563f5f9f916a198c3a72a56ffcea5904b80a0dce48ce760445d65b42083646157d674abc819406756c4712b3fd7dc07725eaea028c205d4d4af5d21292df882b79a1925ffd90f82d9a0b3628098b8527dc899448080a059bab11cf2ac0fa684a7ca11d7901e2a1de1dd256b092ce1eeb5c6c465789508a02bf09f32c09d2f12abad42b8c2d06c12a1e011f2c446ccd81c668a04d83dae91a079d27f1d16617a4c1f041e14a1732f6e57a3c86dd9832716a492506e59ad93e080a0140085077baa38f30b99cb3d2c9019d5d3b014fcf5881030a5a336627b36e91480, 
                0xf8518080808080808080a06675e493d32ffa12e12d8fa0a5a8dc8f915b7926a8bd11de90120aabeb46276f80a0ec20f814c9d1d37c349aab5256147e621967cd386aab5fa4d0ebfe4abbe97d03808080808080, 
                0xe2a020c54f14d0c24cc609cdbaa49b76fb9613b1e9b1aea7cfadfaaf8073e7a7919401
            ] 
        }
    ] 
}



*/
