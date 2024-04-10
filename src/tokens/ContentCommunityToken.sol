// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ERC721} from "solady/tokens/ERC721.sol";
import {LibString} from "solady/utils/LibString.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {ContentRegistry} from "./ContentRegistry.sol";
import {MINTER_ROLES} from "../utils/Roles.sol";

/// @notice Metadata defination of a content
struct Metadata {
    string name;
    bytes32 domainHash;
}

/// @author @KONFeature
/// @title ContentCommunityToken
/// @notice Community NFT made by creator for their community
contract ContentCommunityToken is ERC721, OwnableRoles {
    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @notice Storage for the content registry
    /// @custom:storage-location erc7201:content_registry.main
    struct ContentCommunityTokenStorage {
        uint256 _currentId;
        string _contentName;
    }

    /// Note: This is equivalent to `keccak256(abi.encode(uint256(keccak256("content_community_token.main")) - 1)) & ~bytes32(uint256(0xff));`.
    uint256 private constant _CONTENT_COMMUNITY_TOKEN_LOCATION =
        0x0688948c00e150bf3a594db3a3afdeb26b61dd3914b9aba413c873a9c431ad00;

    function _getStorage() private pure returns (ContentCommunityTokenStorage storage $) {
        assembly {
            $.slot := _CONTENT_COMMUNITY_TOKEN_LOCATION
        }
    }

    /// @dev The content registry
    ContentRegistry private immutable contentRegistry;

    /// @dev The base content id
    uint256 private immutable contentId;

    constructor(ContentRegistry _contentRegistry, uint256 _contentId) {
        contentId = _contentId;
        contentRegistry = _contentRegistry;

        address contentOwner = contentRegistry.ownerOf(_contentId);
        _getStorage()._contentName = contentRegistry.getMetadata(_contentId).name;

        _initializeOwner(contentOwner);
    }

    /* -------------------------------------------------------------------------- */
    /*                    Token description for external tools                    */
    /* -------------------------------------------------------------------------- */

    function name() public view override returns (string memory) {
        return string.concat(_getStorage()._contentName, "CommunityToken");
    }

    function symbol() public pure override returns (string memory) {
        return "CR";
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return string.concat(
            "https://poc-wallet.frak.id/metadata",
            LibString.toString(contentId),
            "/",
            LibString.toString(tokenId),
            ".json"
        );
    }

    /* -------------------------------------------------------------------------- */
    /*                             Mint a new content                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Mint a new token
    function mint(address _to) public returns (uint256 id) {
        ContentCommunityTokenStorage storage crs = _getStorage();
        id = crs._currentId++;
        _mint(_to, id);
    }

    /// @dev Burn a token
    function burn(uint256 _id) public returns (uint256 id) {
        bool isApproved = _isApprovedOrOwner(msg.sender, id);
        if (!isApproved) {
            revert ERC721.NotOwnerNorApproved();
        }

        _burn(_id);
    }
}
