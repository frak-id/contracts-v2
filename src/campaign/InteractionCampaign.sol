// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionType} from "../constants/InteractionType.sol";
import {ProductTypes} from "../constants/ProductTypes.sol";
import {CAMPAIGN_MANAGER_ROLE} from "../constants/Roles.sol";
import {ProductInteractionDiamond} from "../interaction/ProductInteractionDiamond.sol";
import {ProductInteractionManager} from "../interaction/ProductInteractionManager.sol";
import {ProductAdministratorRegistry} from "../registry/ProductAdministratorRegistry.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";

/// @author @KONFeature
/// @title InteractionCampaign
/// @notice Interface representing a campaign around some interactions
/// @custom:security-contact contact@frak.id
abstract contract InteractionCampaign is ReentrancyGuard {
    /// @dev The interaction contract linked to this campaign
    address internal immutable INTERACTION_CONTRACT;

    /// @dev Product id linked to this campaign
    uint256 internal immutable PRODUCT_ID;

    /// @dev The product administrator registry
    ProductAdministratorRegistry internal immutable PRODUCT_ADMINISTRATOR_REGISTRY;

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    error Unauthorized();
    error InactiveCampaign();

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.campaign')) - 1)
    bytes32 private constant _INTERACTION_CAMPAIGN_STORAGE_SLOT =
        0x4502c16acecc256a847201528afb77b0e7b8fd0eb82752bc0f0a6a604a9c2eb4;

    /// @custom:storage-location erc7201:frak.campaign
    struct InteractionCampaignStorage {
        /// @dev Is the campaign running or not
        bool isRunning;
        /// @dev Name of the campaign (string shortened to a bytes32 to reduce storage size)
        bytes32 name;
    }

    function _interactionCampaignStorage() internal pure returns (InteractionCampaignStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _INTERACTION_CAMPAIGN_STORAGE_SLOT
        }
    }

    constructor(
        ProductAdministratorRegistry _productAdministratorRegistry,
        ProductInteractionDiamond _interaction,
        bytes32 _name
    ) {
        PRODUCT_ID = _interaction.getProductId();
        INTERACTION_CONTRACT = address(_interaction);
        PRODUCT_ADMINISTRATOR_REGISTRY = _productAdministratorRegistry;

        // Set the campaign in the running state
        InteractionCampaignStorage storage campaignStorage = _interactionCampaignStorage();
        campaignStorage.name = _name;
        campaignStorage.isRunning = true;
    }

    /* -------------------------------------------------------------------------- */
    /*                               Metadata reader                              */
    /* -------------------------------------------------------------------------- */

    function getMetadata() public view virtual returns (string memory _type, string memory version, bytes32 name);

    function getLink() public view returns (uint256 productId, address interactionContract) {
        return (PRODUCT_ID, INTERACTION_CONTRACT);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Campaign related                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Check if the campaign is active or not
    function isActive() public view virtual returns (bool);

    /// @dev Check if the given campaign support the `_productType`
    function supportProductType(ProductTypes _productType) public view virtual returns (bool);

    /// @dev Handle the interaction logic within the campaign
    function innerHandleInteraction(bytes calldata _data) internal virtual;

    /* -------------------------------------------------------------------------- */
    /*                           Interaction entrypoint                           */
    /* -------------------------------------------------------------------------- */

    /// @dev Handle the given interaction
    function handleInteraction(bytes calldata _data) public onlyInteractionEmitter onlyActiveCampaign {
        innerHandleInteraction(_data);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Running state                               */
    /* -------------------------------------------------------------------------- */

    /// @dev Check if the campaign is running
    function isRunning() public view returns (bool) {
        return _interactionCampaignStorage().isRunning;
    }

    /// @dev Update the campaign running status
    function setRunningStatus(bool _isRunning) external nonReentrant onlyAllowedManager {
        _interactionCampaignStorage().isRunning = _isRunning;
    }

    /* -------------------------------------------------------------------------- */
    /*                              Helper modifiers                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Only allow the call for an authorised mananger
    modifier onlyAllowedManager() {
        bool isAllowed =
            PRODUCT_ADMINISTRATOR_REGISTRY.hasAllRolesOrAdmin(PRODUCT_ID, msg.sender, CAMPAIGN_MANAGER_ROLE);
        if (!isAllowed) revert Unauthorized();
        _;
    }

    /// @dev Only allow the call if the campaign is running
    modifier onlyActiveCampaign() {
        if (!isRunning()) revert InactiveCampaign();
        _;
    }

    /// @dev Only allow the call if the caller is the interaction contract
    modifier onlyInteractionEmitter() {
        if (msg.sender != INTERACTION_CONTRACT) revert Unauthorized();
        _;
    }
}
