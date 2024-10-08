// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionCampaign} from "../campaign/InteractionCampaign.sol";
import {InteractionTypeLib} from "../constants/InteractionType.sol";
import {ProductTypes} from "../constants/ProductTypes.sol";
import {INTERCATION_VALIDATOR_ROLE, UPGRADE_ROLE} from "../constants/Roles.sol";
import {ProductAdministratorRegistry, ProductRoles} from "../registry/ProductAdministratorRegistry.sol";
import {ReferralRegistry} from "../registry/ReferralRegistry.sol";
import {IInteractionFacet} from "./facets/IInteractionFacet.sol";
import {ProductInteractionStorageLib} from "./lib/ProductInteractionStorageLib.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";
import {EIP712} from "solady/utils/EIP712.sol";
import {Initializable} from "solady/utils/Initializable.sol";

/// @title ProductInteractionDiamond
/// @author @KONFeature
/// @notice Interface for a top level product interaction contract
/// @dev This interface is meant to be implemented by a contract that represents a product platform
/// @dev It's act a bit like the diamond operator, having multiple logic contract per product type.
/// @custom:security-contact contact@frak.id
contract ProductInteractionDiamond is ProductInteractionStorageLib, OwnableRoles, EIP712, Initializable {
    using InteractionTypeLib for bytes;

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev error throwned when the signer of an interaction is invalid
    error WrongInteractionSigner();
    /// @dev error throwned when a campaign is already present
    error CampaignAlreadyPresent();
    /// @dev Error when a product type is unhandled
    error UnandledProductType();
    /// @dev Error when we failed to handle an interaction
    error InteractionHandlingFailed();

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event when a campaign is attached to a product
    event CampaignAttached(InteractionCampaign campaign);

    /// @dev Event when a campaign is attached to a product
    event CampaignDetached(InteractionCampaign campaign);

    /* -------------------------------------------------------------------------- */
    /*                                  Constants                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev EIP-712 typehash used to validate the given transaction
    bytes32 private constant VALIDATE_INTERACTION_TYPEHASH =
        keccak256("ValidateInteraction(uint256 productId,bytes32 interactionData,address user)");

    /// @dev The base product referral tree: `keccak256("product-referral-tree")`
    bytes32 private constant BASE_PRODUCT_TREE = 0x256d49b597bf37ff9c8c4e75b5975d725441598c9cc7249f4726439b6b7971bb;

    /// @dev The product id
    uint256 internal immutable PRODUCT_ID;

    /// @dev The referral registry
    ReferralRegistry internal immutable REFERRAL_REGISTRY;

    /// @dev The product administrator registry
    ProductAdministratorRegistry internal immutable PRODUCT_ADMINISTRATOR_REGISTRY;

    /// @dev The product interaction manager address
    address internal immutable INTERACTION_MANAGER;

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    constructor(
        uint256 _productId,
        ReferralRegistry _referralRegistry,
        ProductAdministratorRegistry _productAdministratorRegistry,
        address _interactionManager
    ) {
        // Set immutable variable (since embeded inside the bytecode)
        PRODUCT_ID = _productId;
        REFERRAL_REGISTRY = _referralRegistry;
        PRODUCT_ADMINISTRATOR_REGISTRY = _productAdministratorRegistry;
        INTERACTION_MANAGER = _interactionManager;

        // Disable init on deployed raw instance
        _disableInitializers();

        // The interaction manager is the owner and can trigger updates
        _initializeOwner(_interactionManager);
        _setRoles(_interactionManager, UPGRADE_ROLE);

        // Compute and store the referral tree
        bytes32 tree;
        assembly {
            mstore(0, BASE_PRODUCT_TREE)
            mstore(0x20, _productId)
            tree := keccak256(0, 0x40)
        }
        _productInteractionStorage().referralTree = tree;
        _productInteractionStorage().productId = _productId;
    }

    /* -------------------------------------------------------------------------- */
    /*                             Facets managements                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Set the facets for the given product types
    function setFacets(IInteractionFacet[] calldata facets) external onlyRoles(UPGRADE_ROLE) {
        for (uint256 i = 0; i < facets.length; i++) {
            _setFacet(facets[i]);
        }
    }

    /// @dev Set the facets for the given product types
    function _setFacet(IInteractionFacet _facet) private {
        uint8 denominator = _facet.productTypeDenominator();
        _productInteractionStorage().facets[uint256(denominator)] = _facet;
    }

    /// @dev Delete all the facets matching the given product types
    function deleteFacets(ProductTypes _productTypes) external onlyRoles(UPGRADE_ROLE) {
        uint8[] memory denominators = _productTypes.unwrapToDenominators();
        for (uint256 i = 0; i < denominators.length; i++) {
            delete _productInteractionStorage().facets[uint256(denominators[i])];
        }
    }

    /// @dev Get the facet for the given product type
    function getFacet(uint8 _denominator) external view returns (IInteractionFacet) {
        return _productInteractionStorage().facets[uint256(_denominator)];
    }

    /// @dev Handle an interaction
    function delegateToFacet(uint8 _productTypeDenominator, bytes calldata _call) external {
        // Get the facet matching the product type
        IInteractionFacet facet = _getFacetForDenominator(_productTypeDenominator);

        // Transmit the interaction to the facet
        (bool success,) = address(facet).delegatecall(_call);
        if (!success) {
            revert InteractionHandlingFailed();
        }
    }

    /// @dev Get the facet for the given product type
    function _getFacetForDenominator(uint8 _denominator) internal view returns (IInteractionFacet facet) {
        facet = _productInteractionStorage().facets[uint256(_denominator)];
        if (facet == IInteractionFacet(address(0))) {
            revert UnandledProductType();
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                           Interaction entry point                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Handle an interaction
    function handleInteraction(bytes calldata _interaction, bytes calldata _signature) external {
        // Unpack the interaction
        (uint8 _productTypeDenominator, bytes calldata _facetData) = _interaction.unpackForManager();

        // Validate the interaction
        _validateSenderInteraction(keccak256(_facetData), _signature);

        // Transmit the interaction to the facet
        (bool success, bytes memory outputData) =
            address(_getFacetForDenominator(_productTypeDenominator)).delegatecall(_facetData);
        if (!success) {
            revert InteractionHandlingFailed();
        }

        // Send the interaction to the campaigns if we got some (at least 24 bytes since it should contain the action +
        // user with it)
        if (outputData.length > 23) {
            _sendInteractionToCampaign(outputData);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                           Interaction validation                           */
    /* -------------------------------------------------------------------------- */

    /// @dev Name and version for the EIP-712
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "Frak.ProductInteraction";
        version = "0.0.1";
    }

    /// @dev Expose the domain separator
    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparator();
    }

    /// @dev Check if the provided interaction is valid
    function _validateSenderInteraction(bytes32 _interactionData, bytes calldata _signature) internal view {
        // Rebuild the full typehash
        bytes32 digest = _hashTypedData(
            keccak256(abi.encode(VALIDATE_INTERACTION_TYPEHASH, PRODUCT_ID, _interactionData, msg.sender))
        );

        // Check if the signer as the role to validate the interaction
        if (!hasAnyRole(ECDSA.tryRecoverCalldata(digest, _signature), INTERCATION_VALIDATOR_ROLE)) {
            revert WrongInteractionSigner();
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                            Some metadata reader                            */
    /* -------------------------------------------------------------------------- */

    /// @dev Get the id for the current product
    function getProductId() public view returns (uint256) {
        return PRODUCT_ID;
    }

    /// @dev Get the referral tree for the current product
    function getReferralTree() public view returns (bytes32 tree) {
        return _referralTree();
    }

    /* -------------------------------------------------------------------------- */
    /*                           Campaign related logics                          */
    /* -------------------------------------------------------------------------- */

    /// @dev Send an inbteraction to all the concerned campaigns
    function _sendInteractionToCampaign(bytes memory _data) internal {
        InteractionCampaign[] storage campaigns = _productInteractionStorage().campaigns;
        uint256 length = campaigns.length;
        if (length == 0) {
            return;
        }

        // Treat it as mem safe assembly, even though it's not rly the case
        //  since we are overwriting the two slots before the _data arr, but since that's the last function post execute
        // we don't rly case
        /// @solidity memory-safe-assembly
        assembly {
            // Store the handleInteraction selector + offset
            mstore(sub(_data, 64), 0xc375ab13)
            mstore(sub(_data, 32), 0x20)

            // Build the calldata we will call the campaign with
            let _dataLength := add(mload(_data), 0x60)
            let _dataStart := sub(_data, 0x24)

            // Build the iteration array
            mstore(0, campaigns.slot)
            let _currentOffset := keccak256(0, 0x20)
            let _endOffset := add(_currentOffset, length)

            // Iterate over each campaign and send the data to it
            for {} 1 {} {
                // Call the campaign
                pop(
                    call(
                        gas(),
                        // Campaign address
                        sload(_currentOffset),
                        0,
                        _dataStart,
                        _dataLength,
                        0,
                        0
                    )
                )
                // Move to the next campaign
                _currentOffset := add(_currentOffset, 1)
                // If we reached the end, we exit
                if iszero(lt(_currentOffset, _endOffset)) { break }
            }
        }
    }

    /// @dev Activate a new campaign
    function attachCampaign(InteractionCampaign _campaign) external onlyCampaignManager {
        InteractionCampaign[] storage campaigns = _productInteractionStorage().campaigns;

        // Ensure we don't already have this campaign attached
        for (uint256 i = 0; i < campaigns.length; i++) {
            if (address(campaigns[i]) == address(_campaign)) {
                revert CampaignAlreadyPresent();
            }
        }

        // If all good, add it
        emit CampaignAttached(_campaign);
        campaigns.push(_campaign);
    }

    /// @dev Detach multiple campaigns
    function detachCampaigns(InteractionCampaign[] calldata _campaigns) external onlyCampaignManager {
        InteractionCampaign[] storage campaigns = _productInteractionStorage().campaigns;

        for (uint256 i = 0; i < _campaigns.length; i++) {
            _detachCampaign(_campaigns[i], campaigns);
        }
    }

    /// @dev Detach a campaign
    function _detachCampaign(InteractionCampaign _campaign, InteractionCampaign[] storage campaigns) private {
        InteractionCampaign lastCampaign = campaigns[campaigns.length - 1];

        // If the campaign to remove is the last one, directly pop the element out of the array and exit
        if (address(lastCampaign) == address(_campaign)) {
            // Emit the campaign detachment
            emit CampaignDetached(_campaign);
            // Remove the campaign
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
            // Emit the campaign detachment
            emit CampaignDetached(_campaign);
            // If we found the campaign, we replace it by the last item of our campaigns
            campaigns[i] = campaigns[campaigns.length - 1];
            campaigns.pop();
            return;
        }
    }

    /// @dev Get all the campaigns attached to this interaction
    function getCampaigns() external view returns (InteractionCampaign[] memory) {
        return _productInteractionStorage().campaigns;
    }

    /* -------------------------------------------------------------------------- */
    /*                              Roles management                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Grant roles to a user (only or product manager can do that)
    function grantRoles(address user, uint256 roles) public payable override onlyInteractionManager {
        _grantRoles(user, roles);
    }

    /// @dev Revoke roles to a user (only or product manager can do that)
    function revokeRoles(address user, uint256 roles) public payable override onlyInteractionManager {
        _removeRoles(user, roles);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Helper modifiers                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Restrict the execution to the campaign manager or an approved manager
    modifier onlyInteractionManager() {
        PRODUCT_ADMINISTRATOR_REGISTRY.onlyAnyRolesOrOwner(
            PRODUCT_ID, msg.sender, ProductRoles.INTERACTION_OR_ADMINISTRATOR
        );
        _;
    }

    /// @dev Restrict the execution to the campaign manager or an approved manager
    modifier onlyCampaignManager() {
        // If the interaction manager is calling, we don't need to check the roles
        if (msg.sender != INTERACTION_MANAGER) {
            // Otherwise, we need to check the roles
            PRODUCT_ADMINISTRATOR_REGISTRY.onlyAnyRolesOrOwner(
                PRODUCT_ID, msg.sender, ProductRoles.CAMPAIGN_OR_ADMINISTRATOR
            );
        }
        _;
    }
}
