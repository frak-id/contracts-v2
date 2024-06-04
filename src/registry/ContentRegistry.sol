// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ContentTypes} from "../constants/ContentTypes.sol";
import {MINTER_ROLE} from "../constants/Roles.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {ERC721} from "solady/tokens/ERC721.sol";
import {LibString} from "solady/utils/LibString.sol";

/// @notice Metadata defination of a content
struct Metadata {
    ContentTypes contentTypes;
    string name;
    string domain;
}

/// @author @KONFeature
/// @title ContentRegistry
/// @notice Registery for content usable by the Nexus wallet
contract ContentRegistry is ERC721, OwnableRoles {
    error InvalidNameOrDomain();

    error AlreadyExistingContent();

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @notice Storage for the content registry
    /// @custom:storage-location erc7201:content_registry.main
    struct ContentRegistryStorage {
        mapping(uint256 => Metadata) _metadata;
    }

    ///@dev bytes32(uint256(keccak256('frak.registry.content')) - 1)
    uint256 private constant _CONTENT_REGISTRY_STORAGE_SLOT =
        0x56c313dda80793d04a0a01007411cca82592313e657ea2ef71694d8ac8281531;

    function _getStorage() private pure returns (ContentRegistryStorage storage $) {
        assembly {
            $.slot := _CONTENT_REGISTRY_STORAGE_SLOT
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
        return "ContentRegistry";
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
    function mint(ContentTypes _contentTypes, string calldata _name, string calldata _domain)
        public
        onlyRoles(MINTER_ROLE)
        returns (uint256 id)
    {
        if (bytes(_name).length == 0 || bytes(_domain).length == 0) revert InvalidNameOrDomain();

        // Compute the id (keccak of domain)
        id = uint256(keccak256(abi.encodePacked(_domain)));

        // Ensure the content doesn't already exist
        if (isExistingContent(id)) revert AlreadyExistingContent();

        // Store the metadata and mint the content
        _getStorage()._metadata[id] = Metadata({contentTypes: _contentTypes, name: _name, domain: _domain});

        _mint(msg.sender, id);
    }

    /* -------------------------------------------------------------------------- */
    /*                         Metadata related operaitons                        */
    /* -------------------------------------------------------------------------- */

    /// @notice Get the metadata of a content
    function getMetadata(uint256 _contentId) public view returns (Metadata memory) {
        return _getStorage()._metadata[_contentId];
    }

    /// @notice Get the types of a content
    function getContentTypes(uint256 _contentId) public view returns (ContentTypes) {
        return _getStorage()._metadata[_contentId].contentTypes;
    }

    /// @notice Get the metadata of a content
    function isExistingContent(uint256 _contentId) public view returns (bool) {
        return _exists(_contentId);
    }

    /// @notice Update the metadata of a content
    function updateMetadata(uint256 _contentId, ContentTypes _contentTypes, string calldata _name) public {
        // Ensure it's an approved user doing the call
        if (!_isApprovedOrOwner(msg.sender, _contentId)) revert ERC721.NotOwnerNorApproved();
        if (bytes(_name).length == 0) revert InvalidNameOrDomain();

        // Update the metadata
        Metadata storage metadata = _getStorage()._metadata[_contentId];
        metadata.contentTypes = _contentTypes;
        metadata.name = _name;
    }

    /* -------------------------------------------------------------------------- */
    /*                                Roles checker                               */
    /* -------------------------------------------------------------------------- */

    /// @dev Check if the `_caller` is authorized to manage the `_contentId`
    function isAuthorized(uint256 _contentId, address _caller) public view returns (bool) {
        return _isApprovedOrOwner(_caller, _contentId);
    }
}
