// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {RESOLVER_ROLE, REWARDER_ROLE, UPGRADE_ROLE} from "../constants/Roles.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {EnumerableMapLib} from "solady/utils/EnumerableMapLib.sol";
import {Initializable} from "solady/utils/Initializable.sol";
import {LibBytes} from "solady/utils/LibBytes.sol";
import {ReentrancyGuard} from "solady/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {UUPSUpgradeable} from "solady/utils/UUPSUpgradeable.sol";

/// @dev Struct for a single reward operation in batch
struct RewardOp {
    /// @dev true = lock to userId, false = push to wallet
    bool isLock;
    /// @dev userId (if lock) or address cast to bytes32 (if push)
    bytes32 target;
    /// @dev Amount of tokens to reward
    uint256 amount;
    /// @dev Token address
    address token;
    /// @dev Bank address (source of funds)
    address bank;
    /// @dev Attestation data for audit trail
    bytes attestation;
}

/// @dev Struct for a single resolve operation in batch
struct ResolveOp {
    /// @dev User's identity group ID
    bytes32 userId;
    /// @dev Wallet address to bind to
    address wallet;
}

/// @author @KONFeature
/// @title RewarderHub
/// @notice Central hub for managing and distributing rewards across the Frak ecosystem
/// @dev Uses eager resolution pattern - funds moved to claimable when userId is resolved
/// @dev IMPORTANT: Token Compatibility
///      This contract does NOT support:
///      - Fee-on-transfer tokens: The contract credits the full transfer amount to users without
///        measuring actual received amounts. Fee-on-transfer tokens would cause accounting
///        discrepancies where users are credited more than the contract receives.
///      - Rebasing tokens: The contract tracks fixed amounts in storage. Rebasing tokens that
///        change balances over time would cause over/under-collateralization issues.
///      Only use standard ERC20 tokens that transfer the exact requested amount.
/// @custom:security-contact contact@frak.id
contract RewarderHub is OwnableRoles, UUPSUpgradeable, Initializable, ReentrancyGuard {
    using SafeTransferLib for address;
    using LibBytes for bytes32;
    using EnumerableMapLib for EnumerableMapLib.AddressToUint256Map;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Emitted when a reward is pushed directly to a wallet
    event RewardPushed(
        address indexed wallet, address token, address bank, uint256 amount, bytes attestation
    );

    /// @dev Emitted when a reward is locked for an anonymous user
    event RewardLocked(
        bytes32 indexed userId, address token, address bank, uint256 amount, bytes attestation
    );

    /// @dev Emitted when a userId is resolved to a wallet
    event UserIdResolved(bytes32 indexed userId, address wallet);

    /// @dev Emitted when rewards are claimed by a user
    event RewardClaimed(address indexed wallet, address token, uint256 amount);

    /// @dev Emitted when locked rewards are recovered by admin
    event LockedRecovered(bytes32 indexed userId, address token, uint256 amount, address to);

    /* -------------------------------------------------------------------------- */
    /*                                   Errors                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Thrown when an invalid address is provided
    error InvalidAddress();

    /// @dev Thrown when an invalid amount is provided
    error InvalidAmount();

    /// @dev Thrown when trying to resolve an already resolved userId
    error AlreadyResolved();

    /// @dev Thrown when trying to recover rewards for a resolved userId
    error CannotRecoverResolved();

    /// @dev Thrown when there's nothing to claim
    error NothingToClaim();

    /// @dev Thrown when there's nothing to recover
    error NothingToRecover();

    /* -------------------------------------------------------------------------- */
    /*                                   Storage                                  */
    /* -------------------------------------------------------------------------- */

    /// @dev bytes32(uint256(keccak256('frak.reward.hub')) - 1)
    bytes32 private constant _REWARDER_HUB_STORAGE_SLOT =
        0x5765d97f39456ee4cd0e1fa62a9e5c3f6b4a0c7d8e9f0a1b2c3d4e5f6a7b8c9d;

    /// @custom:storage-location erc7201:frak.reward.hub
    struct RewarderHubStorage {
        /// @dev Claimable rewards: wallet => token => amount
        mapping(address wallet => mapping(address token => uint256 amount)) claimable;
        /// @dev Locked rewards for anonymous users: userId => (token => amount) enumerable map
        mapping(bytes32 userId => EnumerableMapLib.AddressToUint256Map) locked;
        /// @dev Resolution mapping: userId => resolved wallet address
        mapping(bytes32 userId => address wallet) resolutions;
    }

    function _storage() private pure returns (RewarderHubStorage storage storagePtr) {
        assembly {
            storagePtr.slot := _REWARDER_HUB_STORAGE_SLOT
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Constructor                                */
    /* -------------------------------------------------------------------------- */

    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the RewarderHub
    /// @param _owner The owner address
    function init(address _owner) external initializer {
        _initializeOwner(_owner);
        _setRoles(_owner, UPGRADE_ROLE);
    }

    /* -------------------------------------------------------------------------- */
    /*                              Admin Functions                               */
    /* -------------------------------------------------------------------------- */

    /// @notice Push a reward directly to a wallet
    /// @param _wallet The recipient wallet address
    /// @param _amount The amount of tokens to reward
    /// @param _token The token address
    /// @param _bank The bank address (source of funds)
    /// @param _attestation Attestation data for audit trail
    function pushReward(address _wallet, uint256 _amount, address _token, address _bank, bytes calldata _attestation)
        external
        onlyRoles(REWARDER_ROLE)
    {
        _pushReward(_wallet, _amount, _token, _bank, _attestation);
    }

    /// @notice Lock a reward for an anonymous user (or auto-forward if already resolved)
    /// @param _userId The user's identity group ID
    /// @param _amount The amount of tokens to reward
    /// @param _token The token address
    /// @param _bank The bank address (source of funds)
    /// @param _attestation Attestation data for audit trail
    function lockReward(bytes32 _userId, uint256 _amount, address _token, address _bank, bytes calldata _attestation)
        external
        onlyRoles(REWARDER_ROLE)
    {
        // Check if userId is already resolved -> auto-forward to wallet
        address resolved = _storage().resolutions[_userId];
        if (resolved != address(0)) {
            _pushReward(resolved, _amount, _token, _bank, _attestation);
            return;
        }

        _lockReward(_userId, _amount, _token, _bank, _attestation);
    }

    /// @notice Execute a batch of reward operations
    /// @dev Gas Optimization: Operations SHOULD be sorted by (bank, token) for optimal gas usage.
    ///      The function aggregates consecutive operations with the same (bank, token) pair into
    ///      a single transfer. Unsorted operations will still execute correctly but may result
    ///      in multiple smaller transfers instead of aggregated ones, consuming more gas.
    ///      Example of optimal sorting: [(bankA, tokenX), (bankA, tokenX), (bankA, tokenY), (bankB, tokenX)]
    ///      Reverts if any transfer fails. Caller should simulate first to ensure success.
    /// @dev Security: nonReentrant guard protects against malicious token callbacks (e.g., ERC777 hooks)
    ///      that could attempt to manipulate state during transfers.
    /// @param _ops Array of reward operations, ideally sorted by (bank, token) for gas efficiency
    function batch(RewardOp[] calldata _ops) external onlyRoles(REWARDER_ROLE) nonReentrant {
        uint256 len = _ops.length;
        if (len == 0) return;

        RewarderHubStorage storage $ = _storage();

        // Track current chunk for deferred transfer
        address currentBank = _ops[0].bank;
        address currentToken = _ops[0].token;
        uint256 pendingAmount;

        for (uint256 i; i < len;) {
            RewardOp calldata op = _ops[i];

            // Chunk boundary - transfer previous chunk
            if (op.bank != currentBank || op.token != currentToken) {
                currentToken.safeTransferFrom(currentBank, address(this), pendingAmount);
                currentBank = op.bank;
                currentToken = op.token;
                pendingAmount = 0;
            }

            // Accumulate for transfer
            pendingAmount += op.amount;

            // Determine wallet: either resolved userId, or direct wallet address
            address wallet;
            if (op.isLock) {
                wallet = $.resolutions[op.target];
            } else {
                wallet = op.target.lsbToAddress();
            }

            // If locked and not resolved -> lock rewards, otherwise push to wallet
            if (op.isLock && wallet == address(0)) {
                EnumerableMapLib.AddressToUint256Map storage lockedPtr = $.locked[op.target];
                (, uint256 current) = lockedPtr.tryGet(op.token);
                lockedPtr.set(op.token, current + op.amount);
                emit RewardLocked(op.target, op.token, op.bank, op.amount, op.attestation);
            } else {
                $.claimable[wallet][op.token] += op.amount;
                emit RewardPushed(wallet, op.token, op.bank, op.amount, op.attestation);
            }

            unchecked {
                ++i;
            }
        }

        // Transfer final chunk
        currentToken.safeTransferFrom(currentBank, address(this), pendingAmount);
    }

    /// @notice Resolve a userId to a wallet address (one-time binding)
    /// @dev Eagerly moves all locked rewards to claimable for the wallet
    /// @param _userId The user's identity group ID
    /// @param _wallet The wallet address to bind to
    function resolveUserId(bytes32 _userId, address _wallet) external onlyRoles(RESOLVER_ROLE) {
        _resolveUserId(_userId, _wallet);
    }

    /// @notice Resolve multiple userIds to wallet addresses in a single transaction
    /// @dev Eagerly moves all locked rewards to claimable for each resolved wallet
    /// @dev Each userId can only be resolved once (reverts if already resolved)
    /// @param _ops Array of resolve operations
    function batchResolve(ResolveOp[] calldata _ops) external onlyRoles(RESOLVER_ROLE) {
        uint256 len = _ops.length;
        if (len == 0) return;

        for (uint256 i; i < len;) {
            ResolveOp calldata op = _ops[i];
            _resolveUserId(op.userId, op.wallet);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Recover locked rewards for an unresolved userId
    /// @param _userId The user's identity group ID
    /// @param _token The token address
    function recoverLocked(bytes32 _userId, address _token) external onlyOwner {
        RewarderHubStorage storage $ = _storage();

        // Can only recover if NOT resolved (no wallet created)
        if ($.resolutions[_userId] != address(0)) revert CannotRecoverResolved();

        (bool exists, uint256 amount) = $.locked[_userId].tryGet(_token);
        if (!exists || amount == 0) revert NothingToRecover();

        $.locked[_userId].remove(_token);

        _token.safeTransfer(msg.sender, amount);

        emit LockedRecovered(_userId, _token, amount, msg.sender);
    }

    /* -------------------------------------------------------------------------- */
    /*                              User Functions                                */
    /* -------------------------------------------------------------------------- */

    /// @notice Claim rewards for a specific token
    /// @param _token The token address to claim
    /// @return claimed The amount claimed
    function claim(address _token) external nonReentrant returns (uint256 claimed) {
        RewarderHubStorage storage $ = _storage();

        claimed = $.claimable[msg.sender][_token];
        if (claimed == 0) revert NothingToClaim();

        $.claimable[msg.sender][_token] = 0;

        _token.safeTransfer(msg.sender, claimed);

        emit RewardClaimed(msg.sender, _token, claimed);
    }

    /// @notice Claim rewards for multiple tokens
    /// @param _tokens Array of token addresses to claim
    /// @return claimed Array of amounts claimed per token
    function claimBatch(address[] calldata _tokens) external nonReentrant returns (uint256[] memory claimed) {
        claimed = new uint256[](_tokens.length);
        RewarderHubStorage storage $ = _storage();

        for (uint256 t; t < _tokens.length;) {
            address token = _tokens[t];
            uint256 amount = $.claimable[msg.sender][token];

            if (amount > 0) {
                $.claimable[msg.sender][token] = 0;
                token.safeTransfer(msg.sender, amount);
                emit RewardClaimed(msg.sender, token, amount);
            }

            claimed[t] = amount;

            unchecked {
                ++t;
            }
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                              View Functions                                */
    /* -------------------------------------------------------------------------- */

    /// @notice Get the claimable amount for a wallet
    /// @param _wallet The wallet address
    /// @param _token The token address
    /// @return amount The claimable amount
    function getClaimable(address _wallet, address _token) external view returns (uint256 amount) {
        return _storage().claimable[_wallet][_token];
    }

    /// @notice Get the locked amount for a userId
    /// @param _userId The user's identity group ID
    /// @param _token The token address
    /// @return amount The locked amount
    function getLocked(bytes32 _userId, address _token) external view returns (uint256 amount) {
        (, amount) = _storage().locked[_userId].tryGet(_token);
    }

    /// @notice Get the resolved wallet for a userId
    /// @param _userId The user's identity group ID
    /// @return wallet The resolved wallet address (address(0) if not resolved)
    function getResolution(bytes32 _userId) external view returns (address wallet) {
        return _storage().resolutions[_userId];
    }

    /// @notice Get all tokens with locked rewards for a userId
    /// @param _userId The user's identity group ID
    /// @return Array of token addresses with locked rewards
    function getLockedTokens(bytes32 _userId) external view returns (address[] memory) {
        return _storage().locked[_userId].keys();
    }

    /* -------------------------------------------------------------------------- */
    /*                            Internal Functions                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Internal push reward implementation
    function _pushReward(address _wallet, uint256 _amount, address _token, address _bank, bytes calldata _attestation)
        internal
    {
        if (_wallet == address(0)) revert InvalidAddress();
        if (_amount == 0) revert InvalidAmount();

        // Transfer tokens from bank to this contract
        _token.safeTransferFrom(_bank, address(this), _amount);

        // Update claimable
        _storage().claimable[_wallet][_token] += _amount;

        emit RewardPushed(_wallet, _token, _bank, _amount, _attestation);
    }

    /// @dev Internal lock reward implementation
    function _lockReward(bytes32 _userId, uint256 _amount, address _token, address _bank, bytes calldata _attestation)
        internal
    {
        if (_userId == bytes32(0)) revert InvalidAddress();
        if (_amount == 0) revert InvalidAmount();

        // Transfer tokens from bank to this contract
        _token.safeTransferFrom(_bank, address(this), _amount);

        // Update locked map (get current + add)
        RewarderHubStorage storage $ = _storage();
        (, uint256 current) = $.locked[_userId].tryGet(_token);
        $.locked[_userId].set(_token, current + _amount);

        emit RewardLocked(_userId, _token, _bank, _amount, _attestation);
    }

    /// @dev Internal resolve userId implementation
    function _resolveUserId(bytes32 _userId, address _wallet) internal {
        if (_wallet == address(0)) revert InvalidAddress();

        RewarderHubStorage storage $ = _storage();
        if ($.resolutions[_userId] != address(0)) revert AlreadyResolved();

        $.resolutions[_userId] = _wallet;

        // Eager resolution: move all locked funds to claimable
        EnumerableMapLib.AddressToUint256Map storage lockedMap = $.locked[_userId];
        uint256 len = lockedMap.length();

        // Iterate and move all to claimable
        for (uint256 i; i < len;) {
            (address token, uint256 amount) = lockedMap.at(i);
            $.claimable[_wallet][token] += amount;

            unchecked {
                ++i;
            }
        }

        // Clear the map (iterate backwards to avoid index shifting)
        for (uint256 i = len; i > 0;) {
            unchecked {
                --i;
            }
            (address token,) = lockedMap.at(i);
            lockedMap.remove(token);
        }

        emit UserIdResolved(_userId, _wallet);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Upgrade                                   */
    /* -------------------------------------------------------------------------- */
    /*                                  Upgrade                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Authorize upgrade - only UPGRADE_ROLE can upgrade
    function _authorizeUpgrade(address newImplementation) internal override onlyRoles(UPGRADE_ROLE) {}
}
