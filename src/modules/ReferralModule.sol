// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {EIP712} from "solady/utils/EIP712.sol";
import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";

/// @author @KONFeature
/// @title ReferralModule
/// @notice Contract providing referral utilities for other contracts / tools
/// @custom:security-contact contact@frak.id
abstract contract ReferralModule is EIP712 {
    /// @dev EIP-712 typehash for the `saveReferrer` method
    bytes32 private constant _SAVE_REFERRER_TYPEHASH =
        keccak256("SaveReferrer(bytes32 tree,address user,address referrer)");

    /* -------------------------------------------------------------------------- */
    /*                                   Event's                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Emitted when a user is referred by another user
    event UserReferred(bytes32 indexed tree, address indexed referer, address indexed referee);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Error when the provided signature is invalid
    error InvalidSignature();

    /// @dev Error when the user already got a referer for the given `tree`
    error AlreadyHaveReferer(bytes32 tree, address currentReferrer);

    /// @dev Error when the user is already in the referrer chain on the given `tree`
    error AlreadyInRefererChain(bytes32 tree);

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    // bytes32(uint256(keccak256('frak.module.referral')) - 1)
    bytes32 private constant REFERRAL_MODULE_STORAGE_SLOT =
        0xb92450f01791992c0c2e8a3e72eb34731c852391a0ef62877b6fcfe6e3795512;

    struct ReferralModuleStorage {
        /// @dev Mapping of custom tree selector to referral tree
        mapping(bytes32 selector => mapping(address referee => address referrer)) referralTrees;
    }

    function _storage() private pure returns (ReferralModuleStorage storage storagePtr) {
        assembly {
            storagePtr.slot := REFERRAL_MODULE_STORAGE_SLOT
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                      Hooks to be implemented if wanted                     */
    /* -------------------------------------------------------------------------- */

    /// @dev hook when a user is referred by another user
    function onUserReferred(bytes32 _selector, address _referrer, address _referee) internal virtual {}

    /* -------------------------------------------------------------------------- */
    /*                               EIP-712 related                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Name and version for the EIP-712
    function _domainNameAndVersion() internal view virtual returns (string memory name, string memory version) {
        name = "FrakModule.Referral";
        version = "0.0.1";
    }

    /* -------------------------------------------------------------------------- */
    /*                        Referral managements methods                        */
    /* -------------------------------------------------------------------------- */

    /// @dev Specify that the `msg.sender` was referred by `_referrer` on the given `_selector`
    function saveReferrer(bytes32 _selector, address _referrer) public {
        _saveReferrer(_selector, msg.sender, _referrer);
    }

    /// @dev Specify that the `_user` was referred by `_referrer` on the given `_selector`, validated via a signature
    function saveReferrer(bytes32 _selector, address _user, address _referrer, bytes calldata _signature) public {
        // Rebuild the digest of signed data
        bytes32 digest = _hashTypedData(keccak256(abi.encode(_SAVE_REFERRER_TYPEHASH, _selector, _user, _referrer)));

        // Ensure the `_user` address match the `_signature`
        bool isValid = SignatureCheckerLib.isValidERC1271SignatureNowCalldata(_user, digest, _signature);
        if (!isValid) revert InvalidSignature();

        // Save the referrer
        _saveReferrer(_selector, _user, _referrer);
    }

    /// @dev Specify that the `_user` was referred by `_referrer` on the given `_selector`
    function _saveReferrer(bytes32 _selector, address _user, address _referrer) private {
        // Get our referral tree
        mapping(address referee => address referrer) storage tree = _storage().referralTrees[_selector];

        // Ensure the user doesn't have a referer yet
        address tmpReferer = tree[_user];
        if (tmpReferer != address(0)) revert AlreadyHaveReferer(_selector, tmpReferer);

        // Explore the chain to ensure we don't have any referral loop
        tmpReferer = tree[_referrer];
        while (tmpReferer != address(0) && tmpReferer != _user) {
            tmpReferer = tree[tmpReferer];
        }
        if (tmpReferer == _user) revert AlreadyInRefererChain(_selector);

        // If it's good, save the referer and emit the event
        tree[_user] = _referrer;

        // Call the hook
        onUserReferred(_selector, _referrer, _user);

        // Emit the event
        emit UserReferred(_selector, _referrer, _user);
    }

    /* -------------------------------------------------------------------------- */
    /*                            External view methods                           */
    /* -------------------------------------------------------------------------- */

    /// @notice Get the referrer of the given `_referee` on the given `_selector`
    function getReferrer(bytes32 _selector, address _referee) public view returns (address referrer) {
        return _storage().referralTrees[_selector][_referee];
    }

    /// @notice Get the referrer of the given `_referee` on the given `_selector`
    /// @dev We are performing double iteration of all the referer here, so:
    /// @dev FOR OFFCHAIN USE ONLY, NEVER CALL ONCHAIN
    function getAllReferrers(bytes32 _selector, address _referee)
        external
        view
        returns (address[] memory referrerChains)
    {
        // Get our tree
        mapping(address referee => address referrer) storage tree = _storage().referralTrees[_selector];

        // Get the length for our final array
        uint256 length;
        address tmpReferee = _referee;
        while (tmpReferee != address(0)) {
            tmpReferee = tree[tmpReferee];
            ++length;
        }

        // Build our output addresses
        referrerChains = new address[](length);

        // Then fill it
        tmpReferee = _referee;
        for (uint256 i = 0; i < length; ++i) {
            tmpReferee = tree[tmpReferee];
            referrerChains[i] = tmpReferee;
        }
    }
}
