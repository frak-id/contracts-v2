// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ContentRegistry} from "../registry/ContentRegistry.sol";
import {ERC6909} from "solady/tokens/ERC6909.sol";
import {LibString} from "solady/utils/LibString.sol";

/// @author @KONFeature
/// @title CommunityToken
/// @notice NFT representing the the community on a given content
/// @notice Each ID is mapped to a content
contract CommunityToken is ERC6909 {
    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @notice Error when a user tries to mint more than one token
    error OnlyOneTokenPerUser();

    /// @notice Error when token doesn't exist
    error TokenDoesntExist();

    /// @notice Error when token isn't approved or isn't the owner
    error NotOwnerNorApproved();

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @notice Storage for the content registry
    /// @custom:storage-location erc7201:community_token.main
    struct CommunityTokenStorage {
        mapping(uint256 contentId => bool isCommunityAllowed) _communityAllowedMap;
    }

    /// Note: This is equivalent to `keccak256(abi.encode(uint256(keccak256("community_token.main")) - 1)) & ~bytes32(uint256(0xff));`.
    uint256 private constant _COMMUNITY_TOKEN_LOCATION =
        0xd5e952dab8d8225d40fd308bb6c9e2137840f17ac27e9ecd99a69b4d89f9b500;

    function _getStorage() private pure returns (CommunityTokenStorage storage $) {
        assembly {
            $.slot := _COMMUNITY_TOKEN_LOCATION
        }
    }

    /// @dev The content registry
    ContentRegistry private immutable contentRegistry;

    /// @dev The base content id
    uint256 private immutable contentId;

    constructor(ContentRegistry _contentRegistry) {
        contentRegistry = _contentRegistry;
    }

    /* -------------------------------------------------------------------------- */
    /*                    Token description for external tools                    */
    /* -------------------------------------------------------------------------- */

    function name(uint256 _id) public view override onlyCommunityAllowed(_id) returns (string memory) {
        // Get the content name
        string memory contentName = contentRegistry.getMetadata(_id).name;
        // And return the full name
        return string.concat(contentName, " - CommunityToken - Frak");
    }

    function symbol(uint256 _id) public view override onlyCommunityAllowed(_id) returns (string memory) {
        // Get the content name
        string memory contentName = contentRegistry.getMetadata(_id).name;
        // Return the symbol
        return string.concat(contentName, "-fCT");
    }

    function tokenURI(uint256 _id) public view override onlyCommunityAllowed(_id) returns (string memory) {
        return string.concat("https://nexus.frak.id/metadata/", LibString.toString(_id), ".json");
    }

    function isEnabled(uint256 _id) public view returns (bool) {
        return _getStorage()._communityAllowedMap[_id];
    }

    /* -------------------------------------------------------------------------- */
    /*               Tranfer hooks (only allow one token per user )               */
    /* -------------------------------------------------------------------------- */

    /// @dev Hook that is called before any transfer of tokens.
    /// This includes minting and burning.
    function _beforeTokenTransfer(address, address to, uint256 id, uint256 amount) internal view override {
        // Ensure we don't mint more than one token per user
        if (amount > 1) {
            revert OnlyOneTokenPerUser();
        }

        //  Ensure the balance won't overflow when the user receive the token (and if that's not a burn)
        if (to != address(0)) {
            if (balanceOf(to, id) > 0) {
                revert OnlyOneTokenPerUser();
            }
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                Mint and burn                               */
    /* -------------------------------------------------------------------------- */

    /// @dev Mint a new token
    function mint(address _to, uint256 _id) public onlyCommunityAllowed(_id) {
        // Mint the token
        _mint(_to, _id, 1);
    }

    /// @dev Burn a token
    function burn(uint256 _id) public {
        _burn(msg.sender, _id, 1);
    }

    /* -------------------------------------------------------------------------- */
    /*                             Creator management                             */
    /* -------------------------------------------------------------------------- */

    /// @dev Permit to the create to approve his communuty token
    function allowCommunityToken(uint256 _id) public {
        address owner = contentRegistry.ownerOf(_id);
        address approvedOperator = contentRegistry.getApproved(_id);

        if (msg.sender != owner && msg.sender != approvedOperator) {
            revert NotOwnerNorApproved();
        }

        _getStorage()._communityAllowedMap[_id] = true;
    }

    /* -------------------------------------------------------------------------- */
    /*                              Helper modifiers                              */
    /* -------------------------------------------------------------------------- */

    modifier onlyCommunityAllowed(uint256 _id) {
        bool isAlllowed = _getStorage()._communityAllowedMap[_id];
        if (!isAlllowed) {
            revert TokenDoesntExist();
        }
        _;
    }
}
