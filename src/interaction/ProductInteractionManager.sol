// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InteractionCampaign} from "../campaign/InteractionCampaign.sol";
import {ProductTypes} from "../constants/ProductTypes.sol";
import {PRODUCT_MANAGER_ROLE, UPGRADE_ROLE} from "../constants/Roles.sol";
import {ICampaignFactory} from "../interfaces/ICampaignFactory.sol";
import {IFacetsFactory} from "../interfaces/IFacetsFactory.sol";
import {ProductAdministratorRegistry} from "../registry/ProductAdministratorRegistry.sol";
import {ProductRegistry} from "../registry/ProductRegistry.sol";
import {ReferralRegistry} from "../registry/ReferralRegistry.sol";
import {InteractionFacetsFactory} from "./InteractionFacetsFactory.sol";
import {ProductInteractionDiamond} from "./ProductInteractionDiamond.sol";
import {IInteractionFacet} from "./facets/IInteractionFacet.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

/// @title ProductInteractionManager
/// @author @KONFeature
/// @notice Top level manager for different types of interactions
/// @custom:security-contact contact@frak.id
contract ProductInteractionManager is OwnableRoles, UUPSUpgradeable, Initializable {
    /* -------------------------------------------------------------------------- */
    /*                                  Constants                                 */
    /* -------------------------------------------------------------------------- */

    /// @dev The referral registry
    ReferralRegistry internal immutable REFERRAL_REGISTRY;

    /// @dev The product registry
    ProductRegistry internal immutable PRODUCT_REGISTRY;

    /// @dev The product administrator registry
    ProductAdministratorRegistry internal immutable PRODUCT_ADMINISTRATOR_REGISTRY;

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    error InteractionContractAlreadyDeployed();

    error CantHandleProductTypes();

    error NoInteractionContractFound();

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event when two wallet are linked together
    ///  Mostly use in case of initial nexus creation, when a burner wallet is linked to a new wallet
    event WalletLinked(address indexed prevWallet, address indexed newWallet);

    /// @dev Event emitted when an interaction contract is deployed
    event InteractionContractDeployed(uint256 indexed productId, ProductInteractionDiamond interactionContract);

    /// @dev Event emitted when an interaction contract is updated
    event InteractionContractUpdated(uint256 productId, ProductInteractionDiamond interactionContract);

    /// @dev Event emitted when an interaction contract is deleted
    event InteractionContractDeleted(uint256 indexed productId, ProductInteractionDiamond interactionContract);

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.interaction.manager')) - 1)
    bytes32 private constant _INTERACTION_MANAGER_STORAGE_SLOT =
        0x53b106ac374d49a224fae3a01f609d01cf52e1b6f965cbfdbbe6a29870a6a161;

    /// @custom:storage-location erc7201:frak.interaction.manager
    struct ProductStorage {
        /// @dev The diamond responsible for the interaction of the product
        ProductInteractionDiamond diamond;
    }

    struct InteractionManagerStorage {
        /// @dev Mapping of product id to the products
        mapping(uint256 productId => ProductStorage) products;
        /// @dev The facets factory we will be using
        IFacetsFactory facetsFactory;
        /// @dev The campaign factory we will be using
        ICampaignFactory campaignFactory;
    }

    function _storage() private pure returns (InteractionManagerStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _INTERACTION_MANAGER_STORAGE_SLOT
        }
    }

    constructor(
        ProductRegistry _productRegistry,
        ReferralRegistry _referralRegistry,
        ProductAdministratorRegistry _productAdministratorRegistry
    ) {
        // Set immutable variable (since embeded inside the bytecode)
        PRODUCT_REGISTRY = _productRegistry;
        REFERRAL_REGISTRY = _referralRegistry;
        PRODUCT_ADMINISTRATOR_REGISTRY = _productAdministratorRegistry;

        // Disable init on deployed raw instance
        _disableInitializers();
    }

    /// @dev Init our contract with the right owner
    function init(address _owner, IFacetsFactory _facetsFactory, ICampaignFactory _campaignFactory)
        external
        initializer
    {
        _initializeOwner(_owner);
        _setRoles(_owner, UPGRADE_ROLE);

        // Set the factories
        _storage().facetsFactory = _facetsFactory;
        _storage().campaignFactory = _campaignFactory;
    }

    /// @dev Update the facets factory
    function updateFacetsFactory(IFacetsFactory _facetsFactory) external onlyRoles(UPGRADE_ROLE) {
        _storage().facetsFactory = _facetsFactory;
    }

    /// @dev Update the campaign factory
    function updateCampaignFactory(ICampaignFactory _campaignFactory) external onlyRoles(UPGRADE_ROLE) {
        _storage().campaignFactory = _campaignFactory;
    }

    /// @dev Check if the given `_user` is allowed to perform action on the given `_productId`
    function isAllowedOnProduct(uint256 _productId, address _user) public view returns (bool) {
        return PRODUCT_ADMINISTRATOR_REGISTRY.hasAllRolesOrAdmin(_productId, _user, PRODUCT_MANAGER_ROLE);
    }

    /* -------------------------------------------------------------------------- */
    /*                           Interaction deployment                           */
    /* -------------------------------------------------------------------------- */

    /// @dev Deploy a new interaction contract for the given `_productId`
    function deployInteractionContract(uint256 _productId) external _onlyAllowedOnProduct(_productId) {
        // Check if we already have an interaction contract for this product
        if (_storage().products[_productId].diamond != ProductInteractionDiamond(address(0))) {
            revert InteractionContractAlreadyDeployed();
        }

        // Deploy the interaction contract
        (bool success, bytes memory data) = address(_storage().facetsFactory).delegatecall(
            abi.encodeWithSelector(
                InteractionFacetsFactory.createProductInteractionDiamond.selector, _productId, owner()
            )
        );
        if (!success) {
            revert(string(data));
        }

        // Get the deployed interaction contract
        ProductInteractionDiamond diamond = abi.decode(data, (ProductInteractionDiamond));

        // Grant the allowance manager role to the referral registry
        bytes32 referralTree = diamond.getReferralTree();
        REFERRAL_REGISTRY.grantAccessToTree(referralTree, address(diamond));

        // Emit the creation event type
        emit InteractionContractDeployed(_productId, diamond);

        // Save the interaction contract
        _storage().products[_productId].diamond = diamond;
    }

    /// @dev Deploy a new interaction contract for the given `_productId`
    function updateInteractionContract(uint256 _productId) external _onlyAllowedOnProduct(_productId) {
        // Fetch the current interaction contract
        ProductInteractionDiamond interactionContract = getInteractionContract(_productId);

        // Get the list of all the facets we will attach to the contract
        IInteractionFacet[] memory facets =
            _storage().facetsFactory.getFacets(PRODUCT_REGISTRY.getProductTypes(_productId));

        // Send them to the interaction contract
        interactionContract.setFacets(facets);

        // Emit the creation event type
        emit InteractionContractUpdated(_productId, interactionContract);
    }

    /// @dev Delete the interaction contract for the given `_productId`
    function deleteInteractionContract(uint256 _productId) external _onlyAllowedOnProduct(_productId) {
        // Fetch the current interaction contract
        ProductInteractionDiamond interactionContract = getInteractionContract(_productId);

        // Retreive the product types
        ProductTypes productTypes = PRODUCT_REGISTRY.getProductTypes(_productId);

        // Delete the facets
        interactionContract.deleteFacets(productTypes);

        // Get the campaigns and delete them
        InteractionCampaign[] memory campaigns = interactionContract.getCampaigns();
        interactionContract.detachCampaigns(campaigns);

        // Revoke the allowance manager role to the referral registry
        bytes32 referralTree = interactionContract.getReferralTree();
        REFERRAL_REGISTRY.grantAccessToTree(referralTree, address(0)); // Grant the access to nobody

        emit InteractionContractDeleted(_productId, interactionContract);

        // Delete the interaction contract
        delete _storage().products[_productId].diamond;
    }

    /* -------------------------------------------------------------------------- */
    /*                             Campaign deployment                            */
    /* -------------------------------------------------------------------------- */

    /// @dev Attach a new campaign to the given `_productId`
    function deployCampaign(uint256 _productId, bytes4 _campaignIdentifier, bytes calldata _initData)
        public
        _onlyAllowedOnProduct(_productId)
        returns (address campaign)
    {
        // Retreive the interaction contract
        ProductInteractionDiamond interactionContract = getInteractionContract(_productId);

        // Deploy the campaign
        campaign = _storage().campaignFactory.createCampaign(interactionContract, _campaignIdentifier, _initData);

        // Attach the campaign to the interaction contract
        interactionContract.attachCampaign(InteractionCampaign(campaign));
    }

    function detachCampaigns(uint256 _productId, InteractionCampaign[] calldata _campaigns)
        public
        _onlyAllowedOnProduct(_productId)
    {
        // Retreive the interaction contract
        ProductInteractionDiamond interactionContract = getInteractionContract(_productId);

        // Loop over the campaigns and detach them
        interactionContract.detachCampaigns(_campaigns);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Top level interaction                           */
    /* -------------------------------------------------------------------------- */

    /// @dev Retreive the interaction contract for the given product id
    function getInteractionContract(uint256 _productId)
        public
        view
        returns (ProductInteractionDiamond interactionContract)
    {
        // Retreive the interaction contract
        interactionContract = _storage().products[_productId].diamond;
        if (interactionContract == ProductInteractionDiamond(address(0))) revert NoInteractionContractFound();
    }

    /// @dev Emit the wallet linked event (only used for indexing purpose)
    function walletLinked(address _newWallet) external {
        emit WalletLinked(msg.sender, _newWallet);
        // todo: propagate the event to each referral trees
    }

    /* -------------------------------------------------------------------------- */
    /*                                Some helpers                                */
    /* -------------------------------------------------------------------------- */

    /// @dev Upgrade check
    function _authorizeUpgrade(address newImplementation) internal override onlyRoles(UPGRADE_ROLE) {}

    /// @dev Modifier to only allow call from an allowed operator
    modifier _onlyAllowedOnProduct(uint256 _productId) {
        bool isAllowed = PRODUCT_ADMINISTRATOR_REGISTRY.hasAllRolesOrAdmin(_productId, msg.sender, PRODUCT_MANAGER_ROLE);
        if (!isAllowed) revert Unauthorized();
        _;
    }
}
