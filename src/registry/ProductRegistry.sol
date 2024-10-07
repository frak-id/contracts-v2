// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ProductTypes} from "../constants/ProductTypes.sol";
import {MINTER_ROLE} from "../constants/Roles.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {LibString} from "solady/utils/LibString.sol";

/// @notice Metadata defination of a product
struct Metadata {
    ProductTypes productTypes;
    bytes32 name;
    string domain;
    string customMetadataUrl;
}

/// @author @KONFeature
/// @title ProductRegistry
/// @notice Registery for product usable by the Nexus wallet
contract ProductRegistry is ERC721, OwnableRoles {
    error InvalidNameOrDomain();

    error AlreadyExistingProduct();

    error InvalidOwner();

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when a product is minted
    event ProductMinted(uint256 indexed productId, string domain, ProductTypes productTypes, bytes32 name);

    /// @dev Event emitted when a product is updated
    event ProductUpdated(uint256 indexed productId, ProductTypes productTypes, bytes32 name, string customMetadataUrl);

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @notice Storage for the product registry
    /// @custom:storage-location erc7201:frak.registry.product
    struct ProductRegistryStorage {
        /// @dev Metadata of the each products
        mapping(uint256 productId => Metadata metadata) _metadata;
        // Base default metadata url
        string _baseMetadataUrl;
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
        return "PR";
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        // If we got a custom url, use it
        Metadata storage metadata = _getStorage()._metadata[tokenId];
        if (bytes(metadata.customMetadataUrl).length > 0) return metadata.customMetadataUrl;

        // Else, use the default one
        return string.concat(_getStorage()._baseMetadataUrl, LibString.toString(tokenId), ".json");
    }

    /* -------------------------------------------------------------------------- */
    /*                             Mint a new product                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Mint a new product with the given metadata
    function mint(ProductTypes _productTypes, bytes32 _name, string calldata _domain, address _owner)
        public
        onlyRoles(MINTER_ROLE)
        returns (uint256 id)
    {
        if (_name == bytes32(0) || bytes(_domain).length == 0) revert InvalidNameOrDomain();
        if (_owner == address(0)) revert InvalidOwner();

        // Compute the id (keccak of domain)
        id = uint256(keccak256(abi.encodePacked(_domain)));

        // Ensure the product doesn't already exist
        if (_exists(id)) revert AlreadyExistingProduct();

        // Store the metadata and mint the product
        _getStorage()._metadata[id] =
            Metadata({productTypes: _productTypes, name: _name, domain: _domain, customMetadataUrl: ""});

        // Emit the event
        emit ProductMinted(id, _domain, _productTypes, _name);

        // And mint it
        _safeMint(_owner, id);
    }

    /* -------------------------------------------------------------------------- */
    /*                         Metadata related operaitons                        */
    /* -------------------------------------------------------------------------- */

    /// @notice Update the base metadata url
    function setMetadataUrl(string calldata _baseMetadataUrl) public onlyOwner {
        _getStorage()._baseMetadataUrl = _baseMetadataUrl;
    }

    /// @notice Get the metadata of a product
    function getMetadata(uint256 _productId) public view returns (Metadata memory) {
        return _getStorage()._metadata[_productId];
    }

    /// @notice Get the types of a product
    function getProductTypes(uint256 _productId) public view returns (ProductTypes) {
        return _getStorage()._metadata[_productId].productTypes;
    }

    /// @notice Update the metadata of a product
    function updateMetadata(
        uint256 _productId,
        ProductTypes _productTypes,
        bytes32 _name,
        string calldata _customMetadataUrl
    ) public {
        // Ensure it's an approved user doing the call
        if (!_isApprovedOrOwner(msg.sender, _productId)) revert ERC721.NotOwnerNorApproved();
        if (_name == bytes32(0)) revert InvalidNameOrDomain();

        // Update the metadata
        Metadata storage metadata = _getStorage()._metadata[_productId];
        metadata.productTypes = _productTypes;
        metadata.name = _name;

        // If custom metadata provided, update it
        if (bytes(_customMetadataUrl).length > 0) {
            metadata.customMetadataUrl = _customMetadataUrl;
        }

        // Emit the event
        emit ProductUpdated(_productId, _productTypes, _name, _customMetadataUrl);
    }
}
