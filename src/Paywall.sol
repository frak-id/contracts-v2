// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import { ContentRegistry } from "./tokens/ContentRegistry.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";

/// @author @KONFeature
/// @title Paywall
/// @notice Contract in charge of receiving paywall payment and distribute the amount to the content creator
/// @custom:security-contact contact@frak.id
contract Paywall {
    using SafeTransferLib for address;

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Error when the price isn't known for the given content
    error PriceIndexOutOfBound(uint256 priceIndex);

    /// @dev Error when the user already unlocked the article
    error ArticleAlreadyUnlocked(uint256 contentId, bytes32 articleId);

    /// @dev Error when the user already unlocked the article
    error ArticlePriceDisabled(uint256 contentId, bytes32 articleId, uint256 priceIndex);

    /// @dev Error when the price is zero
    error PriceCannotBeZero();

    error NotAuthorized();
    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Event emitted when a user paid an article
    event PaidItemUnlocked(
        uint256 indexed contentId,
        bytes32 indexed articleId,
        address indexed user,
        uint256 paidAmount,
        uint48 allowedUntil
    );

    /* -------------------------------------------------------------------------- */
    /*                                  Structs                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Represent unlock prices for an article
    struct UnlockPrice {
        /// The price, in gwei, to access the article
        uint256 price;
        // The allowance time, in seconds, for the user to access the article, take up 4 bytes, 28 remains
        uint32 allowanceTime;
        // Check if this price is enabled or not
        bool isPriceEnabled;
    }

    /// @dev Represent content paywall
    struct ContentPaywall {
        /// The different prices to access this content
        UnlockPrice[] prices;
    }

    /// @dev Represent the unlock status for a given user
    struct UnlockStatus {
        uint48 remainingTime;
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev The percentage of fees going to the frak labs company
    uint256 private constant FEE_PERCENT = 2;

    /// @dev All the prices for a content
    /// TODO: should remove the id from the unlock price since redundant with the mapping key
    mapping(uint256 contentId => ContentPaywall) private contentPaywall;

    /// @dev Storage of allowance for a given user, on a given article
    mapping(uint256 contentId => mapping(bytes32 articleId => mapping(address user => uint256 validUntil))) private
        unlockedUntilForUser;

    /// @dev Fraktion token access
    ContentRegistry private contentRegistry;

    /// @dev Address of the frak labs wallet
    address private paymentToken;

    constructor(
        address _tokenAddr,
        address _contentRegistry
    ) {
        paymentToken = _tokenAddr;
        contentRegistry = ContentRegistry(_contentRegistry);
    }

    /// @dev Unlock the access to the given `articleId` on the `contentId` for the given `msg.sender`, using the given
    /// `priceId`
    function unlockAccess(uint256 _contentId, bytes32 _articleId, uint256 _priceIndex) external {
        // Check if the price is in the content
        ContentPaywall storage paywall = contentPaywall[_contentId];
        if (_priceIndex >= paywall.prices.length) {
            revert PriceIndexOutOfBound(_priceIndex);
        }

        // Check if the user has already access to the article
        mapping(address user => uint256 validUntil) storage userUnlockedUntil =
            unlockedUntilForUser[_contentId][_articleId];
        uint256 currentUnlockedUntil = userUnlockedUntil[msg.sender];
        if (currentUnlockedUntil > block.timestamp) {
            revert ArticleAlreadyUnlocked(_contentId, _articleId);
        }

        // Otherwise, fetch the price
        UnlockPrice memory unlockPrice = paywall.prices[_priceIndex];
        if (!unlockPrice.isPriceEnabled) {
            revert ArticlePriceDisabled(_contentId, _articleId, _priceIndex);
        }

        // Compute the new unlocked until
        uint256 newUnlockedUntil = block.timestamp + unlockPrice.allowanceTime;

        // Get the owner of this content
        address contentOwner = contentRegistry.ownerOf(_contentId);
        address user = msg.sender;

        // Emit the unlock event
        emit PaidItemUnlocked(_contentId, _articleId, user, unlockPrice.price, uint48(newUnlockedUntil));

        // Transfer the FRK amount to the owner
        paymentToken.safeTransferFrom(user, contentOwner, unlockPrice.price);

        // Save the unlock status for this article
        userUnlockedUntil[user] = newUnlockedUntil;
    }

    /// @dev Get all the article prices for the given content
    /// @return prices The different prices to access the content
    function getContentPrices(uint256 _contentId) external view returns (UnlockPrice[] memory prices) {
        ContentPaywall storage paywall = contentPaywall[_contentId];
        return paywall.prices;
    }

    /// @dev Check if the access to an `item` on a `contentId` by the given `user` is allowed
    /// @return isAllowed True if the access is allowed, false otherwise
    /// @return allowedUntil The timestamp until the access is allowed, uint48.max if the access is allowed forever
    function isReadAllowed(
        uint256 contentId,
        bytes32 articleId,
        address user
    )
        external
        view
        returns (bool isAllowed, uint256 allowedUntil)
    {
        // Fetch the unlock status for the given user
        uint256 unlockedUntil = unlockedUntilForUser[contentId][articleId][user];
        if (unlockedUntil == 0) {
            return (false, 0);
        }

        // Otherwise, compare it to the current timestamp
        return (unlockedUntil > block.timestamp, unlockedUntil);
    }

    /* -------------------------------------------------------------------------- */
    /*                          Global paywall management                         */
    /* -------------------------------------------------------------------------- */

    /// @dev Enable the paywall globally for the given content
    function disablePaywall(uint256 _contentId) external onlyContentOwner(_contentId) {
        // Remove all the prices
        delete contentPaywall[_contentId];
    }

    /// @dev Add a new price for the given `_contentId`
    function addPrice(
        uint256 _contentId,
        UnlockPrice calldata price
    )
        external
        onlyContentOwner(_contentId)
    {
        // Check the price
        if (price.price == 0) {
            revert PriceCannotBeZero();
        }

        // Add the price
        ContentPaywall storage paywall = contentPaywall[_contentId];
        paywall.prices.push(price);
    }

    /// @dev Update the price at the given `_priceIndex` for the given `_contentId`
    function updatePrice(
        uint256 _contentId,
        uint256 _priceIndex,
        UnlockPrice calldata _price
    )
        external
        onlyContentOwner(_contentId)
    {
        // Check the price
        if (_price.price == 0) {
            revert PriceCannotBeZero();
        }

        // Check if the price is in the content
        ContentPaywall storage paywall = contentPaywall[_contentId];
        if (_priceIndex >= paywall.prices.length) {
            revert PriceIndexOutOfBound(_priceIndex);
        }

        // Update the price
        paywall.prices[_priceIndex] = _price;
    }

    /// @dev Modifier to only allow the content owner to call the function
    modifier onlyContentOwner(uint256 _contentId) {
        if (contentRegistry.ownerOf(_contentId) != msg.sender) revert NotAuthorized();
        _;
    }
}
