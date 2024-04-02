// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ERC721} from "solady/tokens/ERC721.sol";
import {LibString} from "solady/utils/LibString.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {MINTER_ROLES} from "../utils/Roles.sol";

/// @notice Metadata defination of a content
struct Metadata {
    string name;
    bytes32 domainHash;
}

/// @author @KONFeature
/// @title ContentRegistry
/// @notice Registery for content usable by the Nexus wallet
contract ContentRegistry is ERC721, OwnableRoles {
    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @notice Storage for the content registry
    /// @custom:storage-location erc7201:content_registry.main
    struct ContentRegistryStorage {
        uint256 _currentId;
        mapping(uint256 => Metadata) _metadata;
    }

    /// Note: This is equivalent to `keccak256(abi.encode(uint256(keccak256("content_registry.main")) - 1)) & ~bytes32(uint256(0xff));`.
    uint256 private constant _CONTENT_REGISTRY_STORAGE_LOCATION =
        0x8e43442a1fbf8d3ad0b551d088a362eef471c3bf2e371b71a80289f260c5b100;

    function _getStorage() private pure returns (ContentRegistryStorage storage $) {
        assembly {
            $.slot := _CONTENT_REGISTRY_STORAGE_LOCATION
        }
    }

    constructor(address _owner) {
        _initializeOwner(_owner);
        _setRoles(_owner, MINTER_ROLES);
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
        return string.concat("https://content.frak.id/metadata", LibString.toString(tokenId), ".json");
    }

    /* -------------------------------------------------------------------------- */
    /*                             Mint a new content                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Mint a new content with the given metadata
    function mint(bytes calldata _metadata) public onlyRoles(MINTER_ROLES) returns (uint256 id) {
        ContentRegistryStorage storage crs = _getStorage();
        id = crs._currentId++;
        crs._metadata[id] = abi.decode(_metadata, (Metadata));
        _mint(msg.sender, id);
    }

    /* -------------------------------------------------------------------------- */
    /*                         Metadata related operaitons                        */
    /* -------------------------------------------------------------------------- */

    /// @notice Get the metadata of a content
    function getMetadata(uint256 tokenId) public view returns (Metadata memory) {
        return _getStorage()._metadata[tokenId];
    }

    /// @notice Update the metadata of a content
    function updateMetadata(uint256 tokenId, Metadata calldata _metadata) public {
        // Ensure it's an approved user doing the call
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert ERC721.NotOwnerNorApproved();

        // Update the metadata
        _getStorage()._metadata[tokenId] = _metadata;
    }
}
