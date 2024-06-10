// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionCampaign} from "../campaign/InteractionCampaign.sol";
import {ContentTypes} from "../constants/ContentTypes.sol";
import {InteractionType, InteractionTypeLib} from "../constants/InteractionType.sol";
import {CAMPAIGN_MANAGER_ROLE, INTERCATION_VALIDATOR_ROLE, UPGRADE_ROLE} from "../constants/Roles.sol";
import {ReferralRegistry} from "../registry/ReferralRegistry.sol";
import {IInteractionFacet} from "./facets/IInteractionFacet.sol";
import {ContentInteractionStorageLib} from "./lib/ContentInteractionStorageLib.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {EIP712} from "solady/utils/EIP712.sol";
import {Initializable} from "solady/utils/Initializable.sol";

/// @title ContentInteractionDiamond
/// @author @KONFeature
/// @notice Interface for a top level content interaction contract
/// @dev This interface is meant to be implemented by a contract that represents a content platform
/// @dev It's act a bit like the diamond operator, having multiple logic contract per content type.
/// @custom:security-contact contact@frak.id
contract ContentInteractionDiamond is ContentInteractionStorageLib, OwnableRoles, EIP712, Initializable {
    using InteractionTypeLib for bytes;

    /// @dev error throwned when the signer of an interaction is invalid
    error WrongInteractionSigner();
    /// @dev error throwned when a campaign is already present
    error CampaignAlreadyPresent();
    /// @dev Error when a content type is unhandled
    error UnandledContentType();
    /// @dev Error when we failed to handle an interaction
    error InteractionHandlingFailed();

    /// @dev EIP-712 typehash used to validate the given transaction
    bytes32 private constant _VALIDATE_INTERACTION_TYPEHASH =
        keccak256("ValidateInteraction(uint256 contentId,bytes32 interactionData,address user,uint256 nonce)");

    /// @dev The base content referral tree: `keccak256("ContentReferralTree")`
    bytes32 private constant _BASE_CONTENT_TREE = 0x3d16196f272c96153eabc4eb746e08ae541cf36535edb959ed80f5e5169b6787;

    /// @dev The content id
    uint256 internal immutable _CONTENT_ID;

    /// @dev The referral registry
    ReferralRegistry internal immutable _REFERRAL_REGISTRY;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    constructor(
        uint256 _contentId,
        ReferralRegistry _referralRegistry,
        address _interactionMananger,
        address _interactionManangerOwner,
        address _contentOwner
    ) {
        // Set immutable variable (since embeded inside the bytecode)
        _CONTENT_ID = _contentId;
        _REFERRAL_REGISTRY = _referralRegistry;

        // Disable init on deployed raw instance
        _disableInitializers();

        // Global owner is the same as the interaction manager owner
        _initializeOwner(_interactionManangerOwner);
        _setRoles(_interactionManangerOwner, UPGRADE_ROLE);
        // The interaction manager can trigger updates
        _setRoles(_interactionMananger, UPGRADE_ROLE | CAMPAIGN_MANAGER_ROLE);
        // The content owner can manage almost everything
        _setRoles(_contentOwner, INTERCATION_VALIDATOR_ROLE | UPGRADE_ROLE);

        // Compute and store the referral tree
        bytes32 tree;
        assembly {
            mstore(0, _BASE_CONTENT_TREE)
            mstore(0x20, _contentId)
            tree := keccak256(0, 0x40)
        }
        _contentInteractionStorage().referralTree = tree;
    }

    /* -------------------------------------------------------------------------- */
    /*                             Facets managements                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Set the facets for the given content types
    function setFacets(IInteractionFacet[] calldata facets) external onlyRoles(UPGRADE_ROLE) {
        for (uint256 i = 0; i < facets.length; i++) {
            _setFacet(facets[i]);
        }
    }

    /// @dev Set the facets for the given content types
    function _setFacet(IInteractionFacet _facet) private {
        uint8 denominator = _facet.contentTypeDenominator();
        _contentInteractionStorage().facets[uint256(denominator)] = _facet;
    }

    /// @dev Delete all the facets matching the given content types
    function deleteFacets(ContentTypes _contentTypes) external onlyRoles(UPGRADE_ROLE) {
        uint8[] memory denominators = _contentTypes.unwrapToDenominators();
        for (uint256 i = 0; i < denominators.length; i++) {
            _contentInteractionStorage().facets[uint256(denominators[i])] = IInteractionFacet(address(0));
        }
    }

    /// @dev Get the facet for the given content type
    function getFacet(uint8 _denominator) external view returns (IInteractionFacet) {
        return _contentInteractionStorage().facets[uint256(_denominator)];
    }

    /* -------------------------------------------------------------------------- */
    /*                           Interaction entry point                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Handle an interaction
    function handleInteraction(bytes calldata _interaction, bytes calldata _signature) external {
        // Unpack the interaction
        (uint8 _contentTypeDenominator, bytes calldata _facetData) = _interaction.unpackForManager();

        // Get the facet matching the content type
        IInteractionFacet facet = _contentInteractionStorage().facets[uint256(_contentTypeDenominator)];

        // If we don't have a facet, we revert
        if (facet == IInteractionFacet(address(0))) {
            revert UnandledContentType();
        }

        // Validate the interaction
        _validateInteraction(keccak256(_facetData), msg.sender, _signature);

        // Transmit the interaction to the facet
        (bool success, bytes memory outputData) = address(facet).delegatecall(_facetData);
        if (!success) {
            revert InteractionHandlingFailed();
        }

        // Send the interaction to the campaigns if we got some (at least 24 bytes since it should contain the action + user with it)
        if (outputData.length > 23) {
            _sendInteractionToCampaign(outputData);
        }
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

        // Rebuild the full typehash
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

    /// @dev Get the id for the current content
    function getContentId() public view returns (uint256) {
        return _CONTENT_ID;
    }

    /// @dev Get the referral tree for the current content
    /// @dev keccak256("ContentReferralTree", contentId)
    function getReferralTree() public view returns (bytes32 tree) {
        return _referralTree();
    }

    /* -------------------------------------------------------------------------- */
    /*                           Campaign related logics                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Send an inbteraction to all the concerned campaigns
    function _sendInteractionToCampaign(bytes memory _data) internal {
        InteractionCampaign[] storage campaigns = _contentInteractionStorage().campaigns;
        if (campaigns.length == 0) {
            return;
        }

        // Call the campaign using a try catch to avoid blocking the whole process if a campaign is locked
        for (uint256 i = 0; i < campaigns.length; i++) {
            try campaigns[i].handleInteraction(_data) {} catch {}
        }
    }

    /// @dev Activate a new campaign
    function attachCampaign(InteractionCampaign _campaign) external onlyRoles(CAMPAIGN_MANAGER_ROLE) {
        InteractionCampaign[] storage campaigns = _contentInteractionStorage().campaigns;

        // Ensure we don't already have this campaign attached
        for (uint256 i = 0; i < campaigns.length; i++) {
            if (address(campaigns[i]) == address(_campaign)) {
                revert CampaignAlreadyPresent();
            }
        }

        // If all good, add it
        campaigns.push(_campaign);
    }

    /// @dev Detach multiple campaigns
    function detachCampaigns(InteractionCampaign[] calldata _campaigns) external onlyRoles(CAMPAIGN_MANAGER_ROLE) {
        InteractionCampaign[] storage campaigns = _contentInteractionStorage().campaigns;

        for (uint256 i = 0; i < _campaigns.length; i++) {
            _detachCampaign(_campaigns[i], campaigns);
        }
    }

    /// @dev Detach a campaign
    function _detachCampaign(InteractionCampaign _campaign, InteractionCampaign[] storage campaigns) private {
        InteractionCampaign lastCampaign = campaigns[campaigns.length - 1];

        // If the campaign to remove is the last one, directly pop the element out of the array and exit
        if (address(lastCampaign) == address(_campaign)) {
            lastCampaign.disallowMe();
            campaigns.pop();
            return;
        }

        // If the campaign array only has one element, and it's not the one we want to remove, we exit cause not found
        if (campaigns.length == 1) {
            return;
        }

        // Find the campaign to remove
        for (uint256 i = 0; i < campaigns.length; i++) {
            // If that's not the campaign, we continue
            if (address(campaigns[i]) != address(_campaign)) {
                continue;
            }
            // Remove the roles on the campagn
            campaigns[i].disallowMe();
            // If we found the campaign, we replace it by the last item of our campaigns
            campaigns[i] = campaigns[campaigns.length - 1];
            campaigns.pop();
            return;
        }
    }

    /// @dev Get all the campaigns attached to this interaction
    function getCampaigns() external view returns (InteractionCampaign[] memory) {
        return _contentInteractionStorage().campaigns;
    }
}
