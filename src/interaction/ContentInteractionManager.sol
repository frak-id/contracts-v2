// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {CONTENT_TYPE_PRESS, ContentTypes} from "../constants/ContentTypes.sol";
import {UPGRADE_ROLE} from "../constants/Roles.sol";

import {ContentInteraction} from "../interaction/ContentInteraction.sol";
import {PressInteraction} from "../interaction/PressInteraction.sol";
import {ContentRegistry} from "../registry/ContentRegistry.sol";
import {ReferralRegistry} from "../registry/ReferralRegistry.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {EIP712} from "solady/utils/EIP712.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

/// @title ContentInteractionManager
/// @author @KONFeature
/// @notice Top level manager for different types of interactions
/// @custom:security-contact contact@frak.id
contract ContentInteractionManager is OwnableRoles, UUPSUpgradeable, Initializable {
    /* -------------------------------------------------------------------------- */
    /*                                  Constants                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev The referral registry
    ReferralRegistry internal immutable _REFERRAL_REGISTRY;

    /// @dev The content registry
    ContentRegistry internal immutable _CONTENT_REGISTRY;

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    error InteractionContractAlreadyDeployed();

    error ContentDoesntExist();

    error CantHandleContentTypes();

    error NoInteractionContractFound();

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event when two wallet are linked together
    ///  Mostly use in case of initial nexus creation, when a burner wallet is linked to a new wallet
    event WalletLinked(address indexed prevWallet, address indexed newWallet);

    /// @dev Event emitted when an interaction contract is deployed
    event InteractionContractDeployed(uint256 indexed _contentId, address interactionContract);

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.interaction.manager')) - 1)
    bytes32 private constant _INTERACTION_MANAGER_STORAGE_SLOT =
        0x53b106ac374d49a224fae3a01f609d01cf52e1b6f965cbfdbbe6a29870a6a161;

    struct InteractionManagerStorage {
        /// @dev Mapping of content id to the content interaction contract
        mapping(uint256 _contentId => address) contentInteractions;
    }

    function _storage() private pure returns (InteractionManagerStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _INTERACTION_MANAGER_STORAGE_SLOT
        }
    }

    constructor(ContentRegistry _contentRegistry, ReferralRegistry _referralRegistry) {
        // Set immutable variable (since embeded inside the bytecode)
        _CONTENT_REGISTRY = _contentRegistry;
        _REFERRAL_REGISTRY = _referralRegistry;

        // Disable init on deployed raw instance
        _disableInitializers();
    }

    /// @dev Init our contract with the right owner
    function init(address _owner) external initializer {
        _initializeOwner(_owner);
        _setRoles(_owner, UPGRADE_ROLE);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Interaction deployment                           */
    /* -------------------------------------------------------------------------- */

    /// @dev Deploy a new interaction contract for the given `_contentId`
    function deployInteractionContract(uint256 _contentId) external {
        // Check if we already have an interaction contract for this content
        if (_storage().contentInteractions[_contentId] != address(0)) revert InteractionContractAlreadyDeployed();

        // Retreive the content types, if at 0 it mean that the content doesn't exist
        ContentTypes contentTypes = _CONTENT_REGISTRY.getContentTypes(_contentId);
        if (contentTypes.isEmpty()) revert ContentDoesntExist();

        // Handle the press type of content
        address interactionContract = _deployContractForContentTypes(_contentId, contentTypes);
        if (interactionContract == address(0)) revert CantHandleContentTypes();

        // Retreive the owner of this content
        address contentOwner = _CONTENT_REGISTRY.ownerOf(_contentId);

        // Deploy the proxy arround the contract and init it
        address proxy = LibClone.deployERC1967(interactionContract);
        ContentInteraction(proxy).init(address(this), owner(), contentOwner);

        // Grant the allowance manager role to the referral registry
        bytes32 referralTree = ContentInteraction(proxy).getReferralTree();
        _REFERRAL_REGISTRY.grantAccessToTree(referralTree, proxy);

        // Emit the creation event type
        emit InteractionContractDeployed(_contentId, proxy);

        // Save the interaction contract
        _storage().contentInteractions[_contentId] = proxy;
    }

    /// @dev Deploy the right interaction contract for the given content type
    function _deployContractForContentTypes(uint256 _contentId, ContentTypes _contentTypes)
        private
        returns (address interactionContract)
    {
        // Handle the press type of content
        if (_contentTypes.isPressType()) {
            // Deploy the press interaction contract
            PressInteraction pressInteraction = new PressInteraction(_contentId, address(_REFERRAL_REGISTRY));
            interactionContract = address(pressInteraction);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                            Top level interaction                           */
    /* -------------------------------------------------------------------------- */

    /// @dev Retreive the interaction contract for the given content id
    function getInteractionContract(uint256 _contentId) public view returns (address interactionContract) {
        // Retreive the interaction contract
        interactionContract = _storage().contentInteractions[_contentId];
        if (interactionContract == address(0)) revert NoInteractionContractFound();
    }

    // TODO: Wallet migration interaction

    /// @dev Upgrade check
    function _authorizeUpgrade(address newImplementation) internal override onlyRoles(UPGRADE_ROLE) {}
}
