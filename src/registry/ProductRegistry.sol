// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ProductTypes} from "../constants/ProductTypes.sol";
import {MINTER_ROLE} from "../constants/Roles.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {LibString} from "solady/utils/LibString.sol";

/// @notice Metadata defination of a content
struct Metadata {
    ProductTypes productTypes;
    string name;
    string domain;
}

/// @author @KONFeature
/// @title ProductRegistry
/// @notice Registery for content usable by the Nexus wallet
contract ProductRegistry is ERC721, OwnableRoles {
    error InvalidNameOrDomain();

    error AlreadyExistingProduct();

    error InvalidOwner();

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when a content is minted
    event ProductMinted(uint256 indexed productId, string domain, ProductTypes productTypes, string name);

    /// @dev Event emitted when a content is updated
    event ProductUpdated(uint256 indexed productId, ProductTypes productTypes, string name);

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @notice Storage for the content registry
    /// @custom:storage-location erc7201:frak.registry.product
    struct ProductRegistryStorage {
        /// @dev Metadata of the each products
        mapping(uint256 productId => Metadata metadata) _metadata;
        /// @dev Roles per products and per users
        mapping(uint256 productId => mapping(address user => uint256 roles)) _roles;
    }

    ///@dev bytes32(uint256(keccak256('frak.registry.product')) - 1)
    uint256 private constant PRODUCT_REGISTRY_STORAGE_SLOT =
        0xf9df516f065b012608cb860b47ffdf715a747b8c52bde5c3ad9b08ef8f84b949;

    function _getStorage() private pure returns (ProductRegistryStorage storage $) {
        assembly {
            $.slot := PRODUCT_REGISTRY_STORAGE_SLOT
        }
    }

    constructor(address _owner) {
        _initializeOwner(_owner);
        _setRoles(_owner, MINTER_ROLE);
    }

    /* -------------------------------------------------------------------------- */
    /*                    Token description for external tools                    */
    /* -------------------------------------------------------------------------- */

    function name() public pure override returns (string memory) {
        return "ProductRegistry";
    }

    function symbol() public pure override returns (string memory) {
        return "CR";
    }

    function tokenURI(uint256 tokenId) public pure override returns (string memory) {
        return string.concat("https://content.frak.id/metadata/", LibString.toString(tokenId), ".json");
    }

    /* -------------------------------------------------------------------------- */
    /*                             Mint a new content                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Mint a new content with the given metadata
    function mint(ProductTypes _productTypes, string calldata _name, string calldata _domain, address _owner)
        public
        onlyRoles(MINTER_ROLE)
        returns (uint256 id)
    {
        if (bytes(_name).length == 0 || bytes(_domain).length == 0) revert InvalidNameOrDomain();
        if (_owner == address(0)) revert InvalidOwner();

        // Compute the id (keccak of domain)
        id = uint256(keccak256(abi.encodePacked(_domain)));

        // Ensure the content doesn't already exist
        if (isExistingProduct(id)) revert AlreadyExistingProduct();

        // Store the metadata and mint the content
        _getStorage()._metadata[id] = Metadata({productTypes: _productTypes, name: _name, domain: _domain});

        // Emit the event
        emit ProductMinted(id, _domain, _productTypes, _name);

        // And mint it
        _safeMint(_owner, id);
    }

    /* -------------------------------------------------------------------------- */
    /*                         Metadata related operaitons                        */
    /* -------------------------------------------------------------------------- */

    /// @notice Get the metadata of a content
    function getMetadata(uint256 _productId) public view returns (Metadata memory) {
        return _getStorage()._metadata[_productId];
    }

    /// @notice Get the types of a content
    function getProductTypes(uint256 _productId) public view returns (ProductTypes) {
        return _getStorage()._metadata[_productId].productTypes;
    }

    /// @notice Check if a content exists
    function isExistingProduct(uint256 _productId) public view returns (bool) {
        return _exists(_productId);
    }

    /// @notice Update the metadata of a content
    function updateMetadata(uint256 _productId, ProductTypes _productTypes, string calldata _name) public {
        // Ensure it's an approved user doing the call
        if (!_isApprovedOrOwner(msg.sender, _productId)) revert ERC721.NotOwnerNorApproved();
        if (bytes(_name).length == 0) revert InvalidNameOrDomain();

        // Update the metadata
        Metadata storage metadata = _getStorage()._metadata[_productId];
        metadata.productTypes = _productTypes;
        metadata.name = _name;

        // Emit the event
        emit ProductUpdated(_productId, _productTypes, _name);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Roles checker                               */
    /* -------------------------------------------------------------------------- */

    /// @dev Check if the `_caller` is authorized to manage the `_productId`
    function isAuthorized(uint256 _productId, address _caller) public view returns (bool) {
        return _isApprovedOrOwner(_caller, _productId);
    }
}
