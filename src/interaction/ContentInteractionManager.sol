// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionCampaign} from "../campaign/InteractionCampaign.sol";
import {ContentTypes} from "../constants/ContentTypes.sol";
import {UPGRADE_ROLE} from "../constants/Roles.sol";
import {ContentRegistry} from "../registry/ContentRegistry.sol";
import {ReferralRegistry} from "../registry/ReferralRegistry.sol";
import {ContentInteractionDiamond} from "./ContentInteractionDiamond.sol";
import {InteractionFacetsFactory} from "./InteractionFacetsFactory.sol";
import {IInteractionFacet} from "./facets/IInteractionFacet.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {Initializable} from "solady/utils/Initializable.sol";
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

    /// @dev Event emitted when an interaction contract is deployed
    event InteractionContractDeployed(uint256 indexed contentId, ContentInteractionDiamond interactionContract);

    /// @dev Event emitted when an interaction contract is updated
    event InteractionContractUpdated(uint256 contentId, ContentInteractionDiamond interactionContract);

    /// @dev Event emitted when an interaction contract is deleted
    event InteractionContractDeleted(uint256 indexed contentId, ContentInteractionDiamond interactionContract);

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.interaction.manager')) - 1)
    bytes32 private constant _INTERACTION_MANAGER_STORAGE_SLOT =
        0x53b106ac374d49a224fae3a01f609d01cf52e1b6f965cbfdbbe6a29870a6a161;

    struct InteractionManagerStorage {
        /// @dev Mapping of content id to the content interaction contract
        mapping(uint256 _contentId => ContentInteractionDiamond) contentInteractions;
        /// @dev The facets factory we will be using
        InteractionFacetsFactory facetsFactory;
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
    function init(address _owner, InteractionFacetsFactory _facetsFactory) external initializer {
        _initializeOwner(_owner);
        _setRoles(_owner, UPGRADE_ROLE);

        // Set the facets factory
        _storage().facetsFactory = _facetsFactory;
    }

    /// @dev Update the facets factory
    function updateFacetsFactory(InteractionFacetsFactory _facetsFactory) external onlyRoles(UPGRADE_ROLE) {
        _storage().facetsFactory = _facetsFactory;
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
        if (_storage().contentInteractions[_contentId] != ContentInteractionDiamond(address(0))) {
            revert InteractionContractAlreadyDeployed();
        }

        // Deploy the interaction contract
        (bool success, bytes memory data) = address(_storage().facetsFactory).delegatecall(
            abi.encodeWithSelector(
                InteractionFacetsFactory.createContentInteractionDiamond.selector, _contentId, owner()
            )
        );
        if (!success) {
            revert(string(data));
        }

        // Get the deployed interaction contract
        ContentInteractionDiamond diamond = abi.decode(data, (ContentInteractionDiamond));

        // Grant the allowance manager role to the referral registry
        bytes32 referralTree = diamond.getReferralTree();
        _REFERRAL_REGISTRY.grantAccessToTree(referralTree, address(diamond));

        // Emit the creation event type
        emit InteractionContractDeployed(_contentId, diamond);

        // Save the interaction contract
        _storage().contentInteractions[_contentId] = diamond;
    }

    /// @dev Deploy a new interaction contract for the given `_contentId`
    function updateInteractionContract(uint256 _contentId) external {
        // Ensure the caller is allowed to perform the update
        bool isAllowed = _CONTENT_REGISTRY.isAuthorized(_contentId, msg.sender);
        if (!isAllowed) revert Unauthorized();

        // Fetch the current interaction contract
        ContentInteractionDiamond interactionContract = getInteractionContract(_contentId);

        // Get the list of all the facets we will attach to the contract
        IInteractionFacet[] memory facets =
            _storage().facetsFactory.getFacets(_CONTENT_REGISTRY.getContentTypes(_contentId));

        // Send them to the interaction contract
        interactionContract.setFacets(facets);

        // Emit the creation event type
        emit InteractionContractUpdated(_contentId, interactionContract);
    }

    /// @dev Delete the interaction contract for the given `_contentId`
    function deleteInteractionContract(uint256 _contentId) external {
        // Ensure the caller is allowed to perform the update
        bool isAllowed = _CONTENT_REGISTRY.isAuthorized(_contentId, msg.sender);
        if (!isAllowed) revert Unauthorized();

        // Fetch the current interaction contract
        ContentInteractionDiamond interactionContract = getInteractionContract(_contentId);

        // Retreive the content types
        ContentTypes contentTypes = _CONTENT_REGISTRY.getContentTypes(_contentId);

        // Delete the facets
        interactionContract.deleteFacets(contentTypes);

        // Get the campaigns and delete them
        InteractionCampaign[] memory campaigns = interactionContract.getCampaigns();
        interactionContract.detachCampaigns(campaigns);

        // Revoke the allowance manager role to the referral registry
        bytes32 referralTree = interactionContract.getReferralTree();
        _REFERRAL_REGISTRY.grantAccessToTree(referralTree, address(0)); // Grant the access to nobody

        emit InteractionContractDeleted(_contentId, interactionContract);

        // Delete the interaction contract
        delete _storage().contentInteractions[_contentId];
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
        ContentInteractionDiamond interactionContract = getInteractionContract(_contentId);

        // Attach the campaign to the interaction contract
        interactionContract.attachCampaign(_campaign);

        // Tell the campaign that this interaction is allowed to push events
        _campaign.allowInteractionContract(address(interactionContract));
    }

    function detachCampaigns(uint256 _contentId, InteractionCampaign[] calldata _campaigns) external {
        if (!_CONTENT_REGISTRY.isAuthorized(_contentId, msg.sender)) {
            revert Unauthorized();
        }

        // Retreive the interaction contract
        ContentInteractionDiamond interactionContract = getInteractionContract(_contentId);

        // Loop over the campaigns and detach them
        interactionContract.detachCampaigns(_campaigns);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Top level interaction                           */
    /* -------------------------------------------------------------------------- */

    /// @dev Retreive the interaction contract for the given content id
    function getInteractionContract(uint256 _contentId)
        public
        view
        returns (ContentInteractionDiamond interactionContract)
    {
        // Retreive the interaction contract
        interactionContract = _storage().contentInteractions[_contentId];
        if (interactionContract == ContentInteractionDiamond(address(0))) revert NoInteractionContractFound();
    }

    /// @dev Emit the wallet linked event (only used for indexing purpose)
    function walletLinked(address _newWallet) external {
        emit WalletLinked(msg.sender, _newWallet);
        // todo: propagate the event to each referral trees
    }

    /// @dev Upgrade check
    function _authorizeUpgrade(address newImplementation) internal override onlyRoles(UPGRADE_ROLE) {}
}
