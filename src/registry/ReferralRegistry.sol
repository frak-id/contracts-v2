// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {InvalidSignature} from "../constants/Errors.sol";
import {EIP712} from "solady/utils/EIP712.sol";
import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {REFERRAL_ALLOWANCE_MANAGER_ROLE} from "../constants/Roles.sol";

/// @author @KONFeature
/// @title ReferralRegistry
/// @notice Contract providing referral utilities for other contracts / tools
/// @custom:security-contact contact@frak.id
contract ReferralRegistry is OwnableRoles {
    /* -------------------------------------------------------------------------- */
    /*                                   Event's                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev Emitted when a user is referred by another user
    event UserReferred(bytes32 indexed tree, address indexed referer, address indexed referee);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Error when the caller isn't allowed to update the state on the given tree
    error NotAllowedOnTheGivenTree();

    /// @dev Error when the user already got a referer for the given `tree`
    error AlreadyHaveReferer(bytes32 tree, address currentReferrer);

    /// @dev Error when the user is already in the referrer chain on the given `tree`
    error AlreadyInRefererChain(bytes32 tree);

    /// @dev Error when the referrer in invalid
    error InvalidReferrer();

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.registry.referral')) - 1)
    bytes32 private constant _REFERRAL_REGISTRY_STORAGE_SLOT =
        0x7604630823fe740cd249174fdd8aaffc7f3bd2a8dffc7d7da7625ddeb9cbed9e;

    struct ReferralRegistryStorage {
        /// @dev Mapping of custom tree selector to referral tree
        mapping(bytes32 selector => mapping(address referee => address referrer)) referralTrees;
        /// @dev Mapping of allowed caller to tree selector
        mapping(bytes32 selector => address) treeAllowance;
    }

    function _referralStorage() private pure returns (ReferralRegistryStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _REFERRAL_REGISTRY_STORAGE_SLOT
        }
    }

    constructor(address _owner) {
        _initializeOwner(_owner);
        _setRoles(_owner, REFERRAL_ALLOWANCE_MANAGER_ROLE);
    }

    /* -------------------------------------------------------------------------- */
    /*                            Tree allowance hooks                            */
    /* -------------------------------------------------------------------------- */

    /// @dev Grant the access to the given tree for the given `_caller`
    function grantAccessToTree(bytes32 _selector, address _caller) public onlyRoles(REFERRAL_ALLOWANCE_MANAGER_ROLE) {
        _referralStorage().treeAllowance[_selector] = _caller;
    }

    /// @dev Transfer the access to the given tree for the given `_newCaller`
    function transferAccessToTree(bytes32 _selector, address _newCaller) public {
        ReferralRegistryStorage storage storageRef = _referralStorage();
        if (msg.sender != storageRef.treeAllowance[_selector]) revert NotAllowedOnTheGivenTree();
        storageRef.treeAllowance[_selector] = _newCaller;
    }

    /// @dev Check if the given `_caller` is allowed on the tree `_selector`
    function isAllowedOnTree(bytes32 _selector, address _caller) public view returns (bool) {
        return _referralStorage().treeAllowance[_selector] == _caller;
    }

    /* -------------------------------------------------------------------------- */
    /*                        Referral managements methods                        */
    /* -------------------------------------------------------------------------- */

    /// @notice Specify that the `_user` was referred by `_referrer` on the given `_selector`
    function saveReferrer(bytes32 _selector, address _user, address _referrer) public {
        if (msg.sender != _referralStorage().treeAllowance[_selector]) revert NotAllowedOnTheGivenTree();
        if (_referrer == address(0)) revert InvalidReferrer();

        // Get our referral tree
        mapping(address referee => address referrer) storage tree = _referralStorage().referralTrees[_selector];

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

        // Emit the event
        emit UserReferred(_selector, _referrer, _user);
    }

    /* -------------------------------------------------------------------------- */
    /*                            External view methods                           */
    /* -------------------------------------------------------------------------- */

    /// @notice Get the referrer of the given `_referee` on the given `_selector`
    function getReferrer(bytes32 _selector, address _referee) public view returns (address referrer) {
        return _referralStorage().referralTrees[_selector][_referee];
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
        mapping(address referee => address referrer) storage tree = _referralStorage().referralTrees[_selector];

        // Get the length for our final array
        uint256 length;
        address tmpReferee = _referee;
        while (true) {
            tmpReferee = tree[tmpReferee];
            if (tmpReferee == address(0)) break;
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
