// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import "erc721a/ERC721A.sol";

/// @author @KONFeature
/// @title LaunchCollection
/// @notice NFT collection for the launch of the Nexus wallet
/// @custom:security-contact contact@frak.id
contract LaunchCollection is ERC721A {
    error HasAlreadyMinted();

    constructor() ERC721A("NexusLaunch", "NEXUS") {}

    /// @dev The uri that will host the NFT metadatas
    /// todo
    function _baseURI() internal view override returns (string memory) {
        return "";
    }

    /// @dev Mint a new NFT
    function mint() external payable {
        // Ensure the user has not already minted
        uint256 alreadyMinted = _numberMinted(msg.sender);
        if (alreadyMinted > 0) {
            revert HasAlreadyMinted();
        }

        // Perform the mint
        _mint(msg.sender, 1);
    }
}
