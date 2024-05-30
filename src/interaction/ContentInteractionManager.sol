// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {EIP712} from "solady/utils/EIP712.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";
import {LibClone} from "solady/utils/LibClone.sol";
import {ReferralRegistry} from "../registry/ReferralRegistry.sol";
import {ContentRegistry} from "../registry/ContentRegistry.sol";
import {UPGRADE_ROLE} from "../constants/Roles.sol";
import {CONTENT_TYPE_PRESS} from "../constants/Contents.sol";

/// @title ContentInteractionManager
/// @author @KONFeature
/// @notice Top level manager for different types of interactions
/// @custom:security-contact contact@frak.id
contract ContentInteractionManager is OwnableRoles, UUPSUpgradeable {
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

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event when two wallet are linked together
    ///  Mostly use in case of initial nexus creation, when a burner wallet is linked to a new wallet
    event WalletLinked(address indexed prevWallet, address indexed newWallet);

    /// @dev Event emitted when an interaction contract is deployed
    event InteractionContractDeployed(uint256 indexed contentId, address interactionContract);

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.interaction.manager')) - 1)
    bytes32 private constant _INTERACTION_MANAGER_STORAGE_SLOT =
        0x53b106ac374d49a224fae3a01f609d01cf52e1b6f965cbfdbbe6a29870a6a161;

    struct InteractionManagerStorage {
        /// @dev Mapping of content id to the content interaction contract
        mapping(uint256 contentId => address) contentInteractions;
    }

    function _storage() private pure returns (InteractionManagerStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _INTERACTION_MANAGER_STORAGE_SLOT
        }
    }

    constructor(address _owner, address _referralRegistry, address _contentRegistry) {
        _CONTENT_REGISTRY = ContentRegistry(_contentRegistry);
        _REFERRAL_REGISTRY = ReferralRegistry(_referralRegistry);

        _initializeOwner(_owner);
        _setRoles(_owner, UPGRADE_ROLE);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Interaction deployment                           */
    /* -------------------------------------------------------------------------- */

    /// @dev Deploy a new interaction contract for the given `contentId`
    function deployInteractionContract(uint256 contentId) external {
        // Check if we already have an interaction contract for this content
        if (_storage().contentInteractions[contentId] != address(0)) revert InteractionContractAlreadyDeployed();

        // TODO: Find the right implementation contracts to deploy, and save them
        // TODO: Handle a sort of multicall stuff for multi content type of content??

        bytes32 contentTypes = _CONTENT_REGISTRY.getContentTypes(contentId);
        if (contentTypes == 0) revert ContentDoesntExist();

        // Handle the press type of content
        address interactionContract;
        if (contentTypes & CONTENT_TYPE_PRESS != 0) {
            // Deploy the press interaction contract
            //address interactionContract = LibClone.clone(address(this));
            //PressInteraction(interactionContract).initialize(contentId, msg.sender, address(_REFERRAL_REGISTRY));
        }

        _storage().contentInteractions[contentId] = interactionContract;
        emit InteractionContractDeployed(contentId, interactionContract);
    }

    /// @dev Upgrade check
    function _authorizeUpgrade(address newImplementation) internal override onlyRoles(UPGRADE_ROLE) {}
}
