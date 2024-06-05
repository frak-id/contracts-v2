// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionCampaign} from "../campaign/InteractionCampaign.sol";
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

    error CantHandleContentTypes();

    error NoInteractionContractFound();

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event when two wallet are linked together
    ///  Mostly use in case of initial nexus creation, when a burner wallet is linked to a new wallet
    event WalletLinked(address indexed prevWallet, address indexed newWallet);

    /// @dev Event when a campaign is attached to a content
    event CampaignAttached(uint256 contentId, address campaign);

    /// @dev Event when a campaign is attached to a content
    event CampaignsDetached(uint256 contentId, InteractionCampaign[] campaigns);

    /// @dev Event emitted when an interaction contract is deployed
    event InteractionContractDeployed(uint256 indexed contentId, address interactionContract);

    /// @dev Event emitted when an interaction contract is updated
    event InteractionContractUpdated(uint256 indexed contentId);

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
        // Ensure the caller is allowed to perform the update
        bool isAllowed = _CONTENT_REGISTRY.isAuthorized(_contentId, msg.sender);
        if (!isAllowed) revert Unauthorized();

        // Check if we already have an interaction contract for this content
        if (_storage().contentInteractions[_contentId] != address(0)) revert InteractionContractAlreadyDeployed();

        // Retreive the content types, if at 0 it mean that the content doesn't exist
        ContentTypes contentTypes = _CONTENT_REGISTRY.getContentTypes(_contentId);

        // Handle the press type of content
        address interactionContract = _deployLogicContractForContentTypes(_contentId, contentTypes);

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
    function _deployLogicContractForContentTypes(uint256 _contentId, ContentTypes _contentTypes)
        private
        returns (address interactionContract)
    {
        // Handle the press type of content
        if (_contentTypes.isPressType()) {
            // Deploy the press interaction contract
            PressInteraction pressInteraction = new PressInteraction(_contentId, address(_REFERRAL_REGISTRY));
            return address(pressInteraction);
        }

        // If we can't handle the content type, revert
        revert CantHandleContentTypes();
    }

    /// @dev Deploy a new interaction contract for the given `_contentId`
    function updateInteractionContract(uint256 _contentId) external {
        // Ensure the caller is allowed to perform the update
        bool isAllowed = _CONTENT_REGISTRY.isAuthorized(_contentId, msg.sender);
        if (!isAllowed) revert Unauthorized();

        // Fetch the current interaction contract
        address interactionContract = getInteractionContract(_contentId);

        // Retreive the content types, if at 0 it mean that the content doesn't exist
        ContentTypes contentTypes = _CONTENT_REGISTRY.getContentTypes(_contentId);

        // Deploy the interaction contract
        address logic = _deployLogicContractForContentTypes(_contentId, contentTypes);

        // Update it
        ContentInteraction(interactionContract).upgradeToAndCall(logic, "");

        // Emit the creation event type
        emit InteractionContractUpdated(_contentId);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Campaign deployment                            */
    /* -------------------------------------------------------------------------- */

    /// @dev Attach a new campaign to the given `_contentId`
    function attachCampaign(uint256 _contentId, InteractionCampaign _campaign) external {
        if (!_CONTENT_REGISTRY.isAuthorized(_contentId, msg.sender)) {
            revert Unauthorized();
        }

        // Retreive the interaction contract
        address interactionContract = getInteractionContract(_contentId);

        // Attach the campaign to the interaction contract
        ContentInteraction(interactionContract).attachCampaign(_campaign);

        // Tell the campaign that this interaction is allowed to push events
        _campaign.allowInteractionContract(interactionContract);

        emit CampaignAttached(_contentId, address(_campaign));
    }

    function detachCampaigns(uint256 _contentId, InteractionCampaign[] calldata _campaigns) external {
        if (!_CONTENT_REGISTRY.isAuthorized(_contentId, msg.sender)) {
            revert Unauthorized();
        }

        // Retreive the interaction contract
        address interactionContract = getInteractionContract(_contentId);

        // Loop over the campaigns and detach them
        ContentInteraction(interactionContract).detachCampaigns(_campaigns);

        // Tell the campaign that this interaction is allowed to push events
        emit CampaignsDetached(_contentId, _campaigns);
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

    /// @dev Emit the wallet linked event (only used for indexing purpose)
    function walletLinked(address _newWallet) external {
        emit WalletLinked(msg.sender, _newWallet);
    }

    /// @dev Upgrade check
    function _authorizeUpgrade(address newImplementation) internal override onlyRoles(UPGRADE_ROLE) {}
}
