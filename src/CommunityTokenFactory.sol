// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {ContentRegistry} from "./tokens/ContentRegistry.sol";
import {ContentCommunityToken} from "./tokens/ContentCommunityToken.sol";

/// @author @KONFeature
/// @title CommunityTokenFactory
/// @notice Contract in charge of creating community tokens
/// @custom:security-contact contact@frak.id
contract CommunityTokenFactory {
    error NotAuthorized();
    error AlreadyDeployed();

    /// @dev The content registry
    ContentRegistry private immutable contentRegistry;

    /// @dev map of content id to community token
    mapping(uint256 contentId => address communityToken) private _communityTokens;

    constructor(address _contentRegistry) {
        contentRegistry = ContentRegistry(_contentRegistry);
    }

    /// @notice Create a community token
    /// @param _contentId The content id
    function createCommunityToken(uint256 _contentId) public returns (address) {
        // Only allowed to create a community token if the content is owned by the sender
        if (contentRegistry.ownerOf(_contentId) != msg.sender) {
            revert NotAuthorized();
        }
        // If we already got an address deployed for this content, return it
        if (_communityTokens[_contentId] != address(0)) {
            revert AlreadyDeployed();
        }

        // Create a new community token
        bytes32 salt = bytes32(_contentId);
        ContentCommunityToken communityToken = new ContentCommunityToken{salt: salt}(contentRegistry, _contentId);

        // Save it in our storage
        _communityTokens[_contentId] = address(communityToken);

        // Return it
        return address(communityToken);
    }

    function getCommunityToken(uint256 _contentId) public view returns (address) {
        return _communityTokens[_contentId];
    }
}
