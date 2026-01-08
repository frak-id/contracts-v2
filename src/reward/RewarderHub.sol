// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {REWARDER_ROLE, RESOLVER_ROLE, UPGRADE_ROLE} from "../constants/Roles.sol";
import {OwnableRoles} from "solady/auth/OwnableRoles.sol";
import {Initializable} from "solady/utils/Initializable.sol";
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

/// @author @KONFeature
/// @title RewarderHub
/// @notice Central hub for managing and distributing rewards across the Frak ecosystem
/// @dev Uses lazy resolution pattern for anonymous users who create wallets later
/// @custom:security-contact contact@frak.id
contract RewarderHub is OwnableRoles, UUPSUpgradeable, Initializable, ReentrancyGuard {
    using SafeTransferLib for address;

    /* -------------------------------------------------------------------------- */
    /*                                   Events                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Emitted when a reward is pushed directly to a wallet
    event RewardPushed(
        address indexed wallet, address indexed token, address indexed bank, uint256 amount, bytes attestation
    );

    /// @dev Emitted when a reward is locked for an anonymous user
    event RewardLocked(
        bytes32 indexed userId, address indexed token, address indexed bank, uint256 amount, bytes attestation
    );

    /// @dev Emitted when a userId is resolved to a wallet
    event UserIdResolved(bytes32 indexed userId, address indexed wallet);

    /// @dev Emitted when rewards are claimed by a user
    event RewardClaimed(address indexed wallet, address indexed token, uint256 amount);

    /// @dev Emitted when locked rewards are recovered by admin
    event LockedRecovered(bytes32 indexed userId, address indexed token, uint256 amount, address to);

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

    /// @dev Thrown when bank has insufficient balance
    error InsufficientBalance();

    /// @dev Thrown when bank has insufficient allowance
    error InsufficientAllowance();

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
        /// @dev Locked rewards for anonymous users: userId => token => amount
        mapping(bytes32 userId => mapping(address token => uint256 amount)) locked;
        /// @dev Resolution mapping: userId => resolved wallet address
        mapping(bytes32 userId => address wallet) resolutions;
        /// @dev Reverse mapping for lazy claim: wallet => array of resolved userIds
        mapping(address wallet => bytes32[] userIds) walletUserIds;
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
    /// @param _ops Array of reward operations
    /// @return results Array of booleans indicating success/failure for each operation
    function batch(RewardOp[] calldata _ops) external onlyRoles(REWARDER_ROLE) returns (bool[] memory results) {
        results = new bool[](_ops.length);

        for (uint256 i; i < _ops.length;) {
            RewardOp calldata op = _ops[i];

            // Pre-check: sufficient balance & allowance
            uint256 balance = op.token.balanceOf(op.bank);
            uint256 allowance = _allowance(op.token, op.bank);

            if (balance < op.amount || allowance < op.amount) {
                unchecked {
                    ++i;
                }
                continue;
            }

            // Execute transfer
            bool transferSuccess = _safeTransferFrom(op.token, op.bank, op.amount);
            if (!transferSuccess) {
                unchecked {
                    ++i;
                }
                continue;
            }

            // Update state based on operation type
            if (op.isLock) {
                bytes32 userId = op.target;
                address resolved = _storage().resolutions[userId];

                if (resolved != address(0)) {
                    // Auto-forward to resolved wallet
                    _storage().claimable[resolved][op.token] += op.amount;
                    emit RewardPushed(resolved, op.token, op.bank, op.amount, op.attestation);
                } else {
                    // Lock for anonymous user
                    _storage().locked[userId][op.token] += op.amount;
                    emit RewardLocked(userId, op.token, op.bank, op.amount, op.attestation);
                }
            } else {
                // Push directly to wallet
                address wallet = address(uint160(uint256(op.target)));
                _storage().claimable[wallet][op.token] += op.amount;
                emit RewardPushed(wallet, op.token, op.bank, op.amount, op.attestation);
            }

            results[i] = true;

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Resolve a userId to a wallet address (one-time binding)
    /// @param _userId The user's identity group ID
    /// @param _wallet The wallet address to bind to
    function resolveUserId(bytes32 _userId, address _wallet) external onlyRoles(RESOLVER_ROLE) {
        if (_wallet == address(0)) revert InvalidAddress();
        if (_storage().resolutions[_userId] != address(0)) revert AlreadyResolved();

        _storage().resolutions[_userId] = _wallet;
        _storage().walletUserIds[_wallet].push(_userId);

        emit UserIdResolved(_userId, _wallet);
    }

    /// @notice Recover locked rewards for an unresolved userId
    /// @param _userId The user's identity group ID
    /// @param _token The token address
    function recoverLocked(bytes32 _userId, address _token) external onlyOwner {
        // Can only recover if NOT resolved (no wallet created)
        if (_storage().resolutions[_userId] != address(0)) revert CannotRecoverResolved();

        uint256 amount = _storage().locked[_userId][_token];
        if (amount == 0) revert NothingToRecover();

        delete _storage().locked[_userId][_token];

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

        // 1. Direct claimable
        claimed = $.claimable[msg.sender][_token];
        $.claimable[msg.sender][_token] = 0;

        // 2. Iterate resolved userIds (lazy resolution)
        bytes32[] storage userIds = $.walletUserIds[msg.sender];
        uint256 len = userIds.length;

        for (uint256 i; i < len;) {
            uint256 lockedAmount = $.locked[userIds[i]][_token];
            if (lockedAmount > 0) {
                claimed += lockedAmount;
                delete $.locked[userIds[i]][_token];
            }

            unchecked {
                ++i;
            }
        }

        if (claimed == 0) revert NothingToClaim();

        _token.safeTransfer(msg.sender, claimed);

        emit RewardClaimed(msg.sender, _token, claimed);
    }

    /// @notice Claim rewards for multiple tokens
    /// @param _tokens Array of token addresses to claim
    /// @return claimed Array of amounts claimed per token
    function claimBatch(address[] calldata _tokens) external nonReentrant returns (uint256[] memory claimed) {
        claimed = new uint256[](_tokens.length);
        RewarderHubStorage storage $ = _storage();

        // Cache userIds for this wallet
        bytes32[] storage userIds = $.walletUserIds[msg.sender];
        uint256 userIdsLen = userIds.length;

        for (uint256 t; t < _tokens.length;) {
            address token = _tokens[t];

            // 1. Direct claimable
            uint256 amount = $.claimable[msg.sender][token];
            $.claimable[msg.sender][token] = 0;

            // 2. Iterate resolved userIds
            for (uint256 i; i < userIdsLen;) {
                uint256 lockedAmount = $.locked[userIds[i]][token];
                if (lockedAmount > 0) {
                    amount += lockedAmount;
                    delete $.locked[userIds[i]][token];
                }

                unchecked {
                    ++i;
                }
            }

            if (amount > 0) {
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

    /// @notice Get the total claimable amount for a wallet (includes resolved userIds)
    /// @param _wallet The wallet address
    /// @param _token The token address
    /// @return total The total claimable amount
    function getClaimable(address _wallet, address _token) external view returns (uint256 total) {
        RewarderHubStorage storage $ = _storage();

        // Direct claimable
        total = $.claimable[_wallet][_token];

        // Add resolved userIds amounts
        bytes32[] storage userIds = $.walletUserIds[_wallet];
        uint256 len = userIds.length;

        for (uint256 i; i < len;) {
            total += $.locked[userIds[i]][_token];

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Get the locked amount for a userId
    /// @param _userId The user's identity group ID
    /// @param _token The token address
    /// @return amount The locked amount
    function getLocked(bytes32 _userId, address _token) external view returns (uint256 amount) {
        return _storage().locked[_userId][_token];
    }

    /// @notice Get the resolved wallet for a userId
    /// @param _userId The user's identity group ID
    /// @return wallet The resolved wallet address (address(0) if not resolved)
    function getResolution(bytes32 _userId) external view returns (address wallet) {
        return _storage().resolutions[_userId];
    }

    /// @notice Get all userIds resolved to a wallet
    /// @param _wallet The wallet address
    /// @return userIds Array of resolved userIds
    function getResolvedUserIds(address _wallet) external view returns (bytes32[] memory) {
        return _storage().walletUserIds[_wallet];
    }

    /* -------------------------------------------------------------------------- */
    /*                            Internal Functions                              */
    /* -------------------------------------------------------------------------- */

    /// @dev Internal push reward implementation
    function _pushReward(
        address _wallet,
        uint256 _amount,
        address _token,
        address _bank,
        bytes calldata _attestation
    ) internal {
        if (_wallet == address(0)) revert InvalidAddress();
        if (_amount == 0) revert InvalidAmount();

        // Check balance and allowance
        uint256 balance = _token.balanceOf(_bank);
        if (balance < _amount) revert InsufficientBalance();

        uint256 allowance = _allowance(_token, _bank);
        if (allowance < _amount) revert InsufficientAllowance();

        // Transfer tokens from bank to this contract
        _token.safeTransferFrom(_bank, address(this), _amount);

        // Update claimable
        _storage().claimable[_wallet][_token] += _amount;

        emit RewardPushed(_wallet, _token, _bank, _amount, _attestation);
    }

    /// @dev Internal lock reward implementation
    function _lockReward(
        bytes32 _userId,
        uint256 _amount,
        address _token,
        address _bank,
        bytes calldata _attestation
    ) internal {
        if (_userId == bytes32(0)) revert InvalidAddress();
        if (_amount == 0) revert InvalidAmount();

        // Check balance and allowance
        uint256 balance = _token.balanceOf(_bank);
        if (balance < _amount) revert InsufficientBalance();

        uint256 allowance = _allowance(_token, _bank);
        if (allowance < _amount) revert InsufficientAllowance();

        // Transfer tokens from bank to this contract
        _token.safeTransferFrom(_bank, address(this), _amount);

        // Update locked
        _storage().locked[_userId][_token] += _amount;

        emit RewardLocked(_userId, _token, _bank, _amount, _attestation);
    }

    /// @dev Get allowance using low-level call to handle non-standard tokens
    function _allowance(address _token, address _owner) internal view returns (uint256) {
        (bool success, bytes memory data) =
            _token.staticcall(abi.encodeWithSignature("allowance(address,address)", _owner, address(this)));
        if (success && data.length >= 32) {
            return abi.decode(data, (uint256));
        }
        return 0;
    }

    /// @dev Safe transfer from with return value
    function _safeTransferFrom(address _token, address _from, uint256 _amount) internal returns (bool) {
        (bool success, bytes memory data) =
            _token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", _from, address(this), _amount));
        return success && (data.length == 0 || abi.decode(data, (bool)));
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Upgrade                                   */
    /* -------------------------------------------------------------------------- */

    /// @dev Authorize upgrade - only UPGRADE_ROLE can upgrade
    function _authorizeUpgrade(address newImplementation) internal override onlyRoles(UPGRADE_ROLE) {}
}
