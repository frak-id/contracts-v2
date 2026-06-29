// SPDX-License-Identifier: MIT
pragma solidity >=0.6.2 <0.9.0;

import {Actor} from "./Actor.sol";
import {Clamp} from "./utils/Clamp.sol";
import {DecimalPrinter} from "./utils/DecimalPrinter.sol";
import {Deployer} from "./utils/Deployer.sol";
import {vm} from "./utils/Hevm.sol";
import {Logger} from "./utils/Logger.sol";
import {Math} from "./utils/Math.sol";
import {StringUtils} from "./utils/StringUtils.sol";
import {EnumerableSet} from "./utils/EnumerableSet.sol";
import {MockERC20} from "./utils/MockERC20.sol";

import {LibClone} from "solady/utils/LibClone.sol";
import {REWARDER_ROLE, COMPLIANCE_ROLE, UPGRADE_ROLE} from "src/constants/Roles.sol";
import {CAMPAIGN_BANK_MANAGER_ROLE, CampaignBank} from "src/bank/CampaignBank.sol";
import {RewarderHub, RewardOp, FrozenFundsRecoverOp} from "src/reward/RewarderHub.sol";
import {mUSDToken, MINTER_ROLE} from "src/tokens/mUSDToken.sol";

/// @notice Base contract with state variables and setup functions
abstract contract Base is StringUtils, Clamp, Deployer, Math {
    using DecimalPrinter for uint256;

    string[] internal ACTOR_LABELS = ["Alice", "Bob", "Charlie"];
    uint256 internal constant BLOCK_INTERVAL = 12 seconds;
    uint256 internal constant INITIAL_ETH_BALANCE = 1_000 ether;
    uint256 internal constant INITIAL_TOKEN_BALANCE = 1_000_000e18;
    /// @dev Amount of each reward token deposited into the bank during setup
    uint256 internal constant INITIAL_BANK_FUNDING = 100_000_000e18;

    // ―――――――――――――――――――――――――― Ghosts ――――――――――――――――――――――――――

    struct Ghosts {
        uint256 _placeholder;
    }

    Ghosts internal ghosts;

    // ―――――――――――――――――――――――――― Actors ――――――――――――――――――――――――――

    address[] internal actors;
    address internal actor;
    address internal admin;

    modifier asActor() virtual {
        vm.startPrank(actor);
        _;
        vm.stopPrank();
    }

    modifier asAdmin() virtual {
        vm.startPrank(admin);
        _;
        vm.stopPrank();
    }

    // ―――――――――――――――――――――――― Contracts ―――――――――――――――――――――――――

    /// @dev Central custodial reward hub (UUPS clone, owned by admin)
    RewarderHub public hub;
    /// @dev One merchant escrow bank, owner = admin, bound to the hub
    CampaignBank public bank;
    /// @dev In-repo mock USD reward token (admin holds MINTER_ROLE)
    mUSDToken public musd;
    /// @dev A second standard ERC20 reward token
    MockERC20 public rewardToken;

    /// @dev The set of reward tokens the fuzzer routes through the protocol
    address[] internal tokens;

    // ―――――――――――――――――――――――――― Setup ―――――――――――――――――――――――――――

    function setup() internal {
        setupActors();
        setupProtocol();
        setupTokens();
        setupBank();
        setupActorBalances();
    }

    /// @notice Deploy the RewarderHub behind a minimal-proxy clone and grant admin roles.
    function setupProtocol() internal {
        // Deploy behind a real ERC1967 proxy (the actual UUPS pattern), not a bare minimal clone.
        RewarderHub hubImpl = new RewarderHub();
        hub = RewarderHub(LibClone.deployERC1967(address(hubImpl)));
        hub.init(admin);
        vm.label(address(hub), "RewarderHub");

        // admin is owner + UPGRADE_ROLE after init; also act as rewarder + compliance backend
        hub.grantRoles(admin, REWARDER_ROLE | COMPLIANCE_ROLE);
    }

    /// @notice Deploy the two reward tokens and register them in the token set.
    function setupTokens() internal {
        musd = new mUSDToken(admin);
        vm.label(address(musd), "mUSD");
        rewardToken = new MockERC20(admin, 0, "Reward", "RWD", 18);
        vm.label(address(rewardToken), "RewardToken");

        tokens.push(address(musd));
        tokens.push(address(rewardToken));
    }

    /// @notice Deploy a CampaignBank clone, fund it, and arm its allowance to the hub.
    function setupBank() internal {
        CampaignBank bankImpl = new CampaignBank();
        bank = CampaignBank(LibClone.clone(address(bankImpl)));
        bank.init(admin, address(hub));
        vm.label(address(bank), "CampaignBank");

        // Mint funding to admin (the merchant) and approve the bank to pull it in.
        musd.mint(admin, INITIAL_BANK_FUNDING);
        rewardToken.deal(admin, INITIAL_BANK_FUNDING);
        musd.approve(address(bank), type(uint256).max);
        rewardToken.approve(address(bank), type(uint256).max);

        // Open the bank, deposit funding, and arm the hub's pull allowance.
        bank.setOpen(true);
        for (uint256 i; i < tokens.length; i++) {
            bank.deposit(tokens[i], INITIAL_BANK_FUNDING);
            bank.updateAllowance(tokens[i], type(uint256).max);
        }
    }

    /// @notice Seed each actor with reward-token balances for token-level handlers.
    function setupActorBalances() internal {
        for (uint256 i; i < actors.length; i++) {
            musd.mint(actors[i], INITIAL_TOKEN_BALANCE);
            rewardToken.deal(actors[i], INITIAL_TOKEN_BALANCE);
        }
    }

    function setupActors() internal {
        admin = address(this);
        vm.label(admin, "Admin");

		for (uint256 i; i < ACTOR_LABELS.length; i++) {
			address _actor = address(new Actor{value: INITIAL_ETH_BALANCE}());
            actors.push(_actor);
            if (ACTOR_LABELS.length > i) {
                vm.label(_actor, ACTOR_LABELS[i]);
            }
            // FIXME: Add any required actor setup (e.g. minting tokens, setting allowances, etc.)
            //        If needed, Actor's constructor can also be used for this purpose
		}
        actor = actors[0];
    }

    // ――――――――――――――――――――――――― Helpers ――――――――――――――――――――――――――

    // Maps an arbitrary address to an actor address
    function toActor(address addy) internal view returns (address) {
        return actors[uint256(uint160(addy)) % actors.length];
    }

    // Maps an arbitrary seed to one of the registered reward tokens
    function toToken(uint256 seed) internal view returns (address) {
        return tokens[seed % tokens.length];
    }

    // ERC20 balance of an address for a given token (low-level, mock-safe)
    function tokenBalanceOf(address _token, address _who) internal view returns (uint256) {
        (bool ok, bytes memory data) = _token.staticcall(abi.encodeWithSignature("balanceOf(address)", _who));
        if (ok && data.length >= 32) return abi.decode(data, (uint256));
        return 0;
    }

    // Maps an arbitrary address to an actor address that is different from the current actor
    function toActorNotCurrent(address addy) internal view returns (address) {
        address _actor = actors[uint256(uint160(addy)) % actors.length];
        if (_actor == actor) {
            _actor = actors[(uint256(uint160(addy)) + 1) % actors.length];
        }
        return _actor;
    }

    // Sums the native token balances of all actors
    function sumActorsBalances() internal view returns (uint256 sumOfBalances) {
        for (uint256 i; i < actors.length; i++) {
            sumOfBalances += actors[i].balance;
        }
    }

    // Sums the ERC-20 token balances of all actors for a given token
    function sumActorsERC20Balances(address _token) internal view returns (uint256 sumOfBalances) {
        for (uint256 i; i < actors.length; i++) {
            bytes memory data = abi.encodeWithSignature("balanceOf(address)", actors[i]);
            (bool success, bytes memory result) = _token.staticcall(data);
            require(success, "sumActorsERC20Balances: failed to get balance");
            sumOfBalances += abi.decode(result, (uint256));
        }
    }

    function skipBlocks(uint256 blocks) internal {
        vm.roll(block.number + blocks);
        vm.warp(block.timestamp + blocks * BLOCK_INTERVAL);
    }

    function skipTime(uint256 time) internal {
        uint256 blocks = (time + BLOCK_INTERVAL - 1) / BLOCK_INTERVAL;
        vm.roll(block.number + blocks);
        vm.warp(block.timestamp + time);
    }
}
