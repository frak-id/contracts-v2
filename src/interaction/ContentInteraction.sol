// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {Initializable} from "solady/utils/Initializable.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {EIP712} from "solady/utils/EIP712.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {ReferralRegistry} from "../registry/ReferralRegistry.sol";
import {CAMPAIGN_MANAGER_ROLE, INTERCATION_VALIDATOR_ROLE, UPGRADE_ROLE} from "../constants/Roles.sol";
import {ContentTypes} from "../constants/ContentTypes.sol";

/// @title ContentInteraction
/// @author @KONFeature
/// @notice Interface for a content platform
/// @dev This interface is meant to be implemented by a contract that represents a content platform
/// @custom:security-contact contact@frak.id
abstract contract ContentInteraction is OwnableRoles, EIP712, UUPSUpgradeable, Initializable {
    /// @dev error throwned when the signer of an interaction is invalid
    error WrongInteractionSigner();

    /// @dev EIP-712 typehash used to validate the given transaction
    bytes32 private constant _VALIDATE_INTERACTION_TYPEHASH =
        keccak256("SaveReferrer(uint256 contentId, bytes32 interactionData,address user, uint256 nonce)");

    /// @dev The base content referral tree: `keccak256("ContentReferralTree")`
    bytes32 private constant _BASE_CONTENT_TREE = 0x3d16196f272c96153eabc4eb746e08ae541cf36535edb959ed80f5e5169b6787;

    /// @dev The content id
    uint256 internal immutable _CONTENT_ID;

    /// @dev The referral registry
    ReferralRegistry internal immutable _REFERRAL_REGISTRY;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.content.interaction')) - 1)
    bytes32 private constant _CONTENT_INTERACTION_STORAGE_SLOT =
        0xd966519fe3fe853ea9b03acd8a0422a17006c68dbe1d8fa2b9127b9e8e22eac4;

    struct ContentInteractionStorage {
        /// @dev Nonce for the validation of the interaction
        mapping(bytes32 nonceKey => uint256 nonce) nonces;
    }

    function _contentInteractionStorage() private pure returns (ContentInteractionStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _CONTENT_INTERACTION_STORAGE_SLOT
        }
    }

    constructor(uint256 _contentId, address _referralRegistry) {
        // Set immutable variable (since embeded inside the bytecode)
        _CONTENT_ID = _contentId;
        _REFERRAL_REGISTRY = ReferralRegistry(_referralRegistry);

        // Disable init on deployed raw instance
        _disableInitializers();
    }

    /// @dev Init our contract with the right owner
    function init(address _interactionMananger, address _interactionManangerOwner, address _contentOwner)
        external
        initializer
    {
        // Global owner is the same as the interaction manager owner
        _initializeOwner(_interactionManangerOwner);
        _setRoles(_interactionManangerOwner, UPGRADE_ROLE);
        // The interaction manager can trigger updates
        _setRoles(_interactionMananger, UPGRADE_ROLE);
        // The content owner can manage almost everything
        _setRoles(_contentOwner, CAMPAIGN_MANAGER_ROLE | INTERCATION_VALIDATOR_ROLE | UPGRADE_ROLE);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Referral related                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Save on the registry level that `_user` has been referred by `_referrer`
    function _saveReferrer(address _user, address _referrer) internal {
        _REFERRAL_REGISTRY.saveReferrer(getReferralTree(), _user, _referrer);
    }

    /// @dev Check on the registry if the `_user` has already a referrer
    function _isUserAlreadyReferred(address _user) internal view returns (bool) {
        return _REFERRAL_REGISTRY.getReferrer(getReferralTree(), _user) != address(0);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Interaction validation                           */
    /* -------------------------------------------------------------------------- */

    /// @dev Name and version for the EIP-712
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "Frak.ContentInteraction";
        version = "0.0.1";
    }

    /// @dev Expose the domain separator
    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparator();
    }

    /// @dev Check if the provided interaction is valid
    function _validateInteraction(bytes32 _interactionData, address _user, bytes calldata _signature) internal {
        // Get the key for our nonce
        bytes32 nonceKey;
        assembly {
            mstore(0, _interactionData)
            mstore(0x20, _user)
            nonceKey := keccak256(0, 0x40)
        }

        // Rebuild the full typehas
        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(
                    _VALIDATE_INTERACTION_TYPEHASH,
                    _CONTENT_ID,
                    _interactionData,
                    _user,
                    _contentInteractionStorage().nonces[nonceKey]++
                )
            )
        );

        // Retreive the signer
        address signer = ECDSA.tryRecoverCalldata(digest, _signature);

        // Check if the signer as the role to validate the interaction
        bool isValidSigner = hasAllRoles(signer, INTERCATION_VALIDATOR_ROLE);
        if (!isValidSigner) {
            revert WrongInteractionSigner();
        }
    }

    /// @dev Get the current user nonce for the given interaction
    function getNonceForInteraction(bytes32 _interactionData, address _user) external view returns (uint256) {
        bytes32 nonceKey;
        assembly {
            mstore(0, _interactionData)
            mstore(0x20, _user)
            nonceKey := keccak256(0, 0x40)
        }

        return _contentInteractionStorage().nonces[nonceKey];
    }

    /* -------------------------------------------------------------------------- */
    /*                            Some metadata reader                            */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the type for the current content
    function getContentType() public pure virtual returns (ContentTypes);

    /// @dev Get the id for the current content
    function getContentId() public view returns (uint256) {
        return _CONTENT_ID;
    }

    /// @dev Get the referral tree for the current content
    /// @dev keccak256("ContentReferralTree", contentId)
    function getReferralTree() public view returns (bytes32 tree) {
        uint256 cId = _CONTENT_ID;
        assembly {
            mstore(0, _BASE_CONTENT_TREE)
            mstore(0x20, cId)
            tree := keccak256(0, 0x40)
        }
    }

    /// @dev Upgrade check
    function _authorizeUpgrade(address newImplementation) internal override onlyRoles(UPGRADE_ROLE) {}
}
