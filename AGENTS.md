# AGENTS.md - Frak Contracts v2

Smart contracts for the Frak Nexus ecosystem. Solidity + Foundry stack.

## Quick Reference

```bash
# Build & Test
forge build                          # Build all contracts
forge test                           # Run all tests
forge test -vvv                      # Verbose output with traces
forge test --match-test test_name    # Run single test by name
forge test --match-contract Name     # Run tests in specific contract
forge test --match-path test/path/*  # Run tests matching path

# Linting & Formatting
forge fmt                            # Format all Solidity files
forge fmt --check                    # Check formatting without changes
bun run lint                         # Lint src/**/*.sol with solhint
bun run lint:test                    # Lint test/**/*.sol
bun run lint:script                  # Lint script/**/*.sol

# Heavy testing (extended fuzzing)
FOUNDRY_PROFILE=heavy forge test     # 1024 fuzz runs, deeper invariants

# Generate ABIs for external use
bun run generate                     # Generate TypeScript ABIs via wagmi

# Clean
forge clean                          # Remove build artifacts
```

## Project Structure

```
src/
  campaign/         # Campaign contracts (rewards, referrals, affiliation)
  constants/        # Shared constants (roles, types, errors)
  interaction/      # Diamond pattern interaction contracts + facets
  interfaces/       # Contract interfaces
  kernel/           # Kernel v2 plugins (WebAuthN, delegation)
  modules/          # Utility modules
  oracle/           # Purchase oracle
  registry/         # Core registries (Product, Referral, Administrator)
  tokens/           # Token contracts
  utils/            # Utility libraries

test/               # Test files (mirrors src/ structure)
script/             # Deployment and utility scripts
lib/                # Foundry dependencies (git submodules)
external/           # Generated ABIs for frontend consumption
```

## Code Style Guidelines

### Solidity Version & License
```solidity
// Source files (src/)
// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

// Test files (test/)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
```

### Import Order
Imports are sorted alphabetically. Group by:
1. Local project imports (relative paths)
2. External library imports (solady, forge-std)

```solidity
import {LocalContract} from "../local/Path.sol";
import {AnotherLocal} from "../other/Path.sol";
import {ExternalLib} from "solady/utils/ExternalLib.sol";
import {Test} from "forge-std/Test.sol";
```

### Formatting (enforced by forge fmt)
- Line length: 120 characters
- Number underscores: thousands (e.g., `100_000`)
- Wrap comments: enabled

### Contract Structure
Use section separators for organization:
```solidity
/* -------------------------------------------------------------------------- */
/*                                   Events                                   */
/* -------------------------------------------------------------------------- */

/* -------------------------------------------------------------------------- */
/*                                   Errors                                   */
/* -------------------------------------------------------------------------- */

/* -------------------------------------------------------------------------- */
/*                                   Storage                                  */
/* -------------------------------------------------------------------------- */

/* -------------------------------------------------------------------------- */
/*                              Public Functions                              */
/* -------------------------------------------------------------------------- */
```

### NatSpec Documentation
```solidity
/// @author @KONFeature
/// @title ContractName
/// @notice Brief description of the contract
/// @custom:security-contact contact@frak.id
contract ContractName {
    /// @dev Event emitted when something happens
    event SomethingHappened(uint256 indexed id);

    /// @notice Public function description
    /// @param _param Parameter description
    /// @return returnValue Description of return
    function publicFunc(uint256 _param) public returns (uint256 returnValue) {
```

### Naming Conventions
- **Contracts**: PascalCase (`ProductRegistry`, `InteractionCampaign`)
- **Functions**: camelCase (`getMetadata`, `handleInteraction`)
- **Internal/Private functions**: prefix with `_` (`_validateSender`)
- **Constants**: SCREAMING_SNAKE_CASE (`MINTER_ROLE`, `PRODUCT_ID`)
- **Immutables**: SCREAMING_SNAKE_CASE (`PRODUCT_ADMINISTRATOR_REGISTRY`)
- **Storage variables**: `_prefixed` for internal (`_metadata`)
- **Function parameters**: `_prefixed` (`_productId`, `_owner`)
- **Local variables**: camelCase (`currentIndex`, `productTypes`)

### Error Handling
Use custom errors (gas efficient):
```solidity
error InvalidNameOrDomain();
error AlreadyExistingProduct();
error Unauthorized();

// Usage
if (condition) revert InvalidNameOrDomain();
```

### Storage Patterns (ERC-7201)
Use namespaced storage for upgradeable contracts:
```solidity
/// @custom:storage-location erc7201:frak.registry.product
struct ProductRegistryStorage {
    mapping(uint256 => Metadata) _metadata;
}

/// @dev bytes32(uint256(keccak256('frak.registry.product')) - 1)
uint256 private constant STORAGE_SLOT = 0x...;

function _getStorage() private pure returns (ProductRegistryStorage storage $) {
    assembly {
        $.slot := STORAGE_SLOT
    }
}
```

### Libraries Used
- **solady**: Auth (`OwnableRoles`), tokens (`ERC721`), utils (`LibClone`, `ECDSA`, `EIP712`)
- **forge-std**: Testing (`Test`, `console`, `Vm`)

## Test Conventions

### File Naming
- Test files: `ContractName.t.sol`
- Mock contracts: `MockContractName.sol`

### Test Structure
```solidity
contract ContractNameTest is Test {
    ContractName private contractInstance;
    
    address private owner = makeAddr("owner");
    address private user = makeAddr("user");

    function setUp() public {
        contractInstance = new ContractName(owner);
    }

    function test_functionName_scenario() public {
        // Test implementation
    }

    function test_functionName_RevertCondition() public {
        vm.expectRevert(ContractName.CustomError.selector);
        contractInstance.functionThatReverts();
    }
}
```

### Base Test Contract
Use `EcosystemAwareTest` for tests requiring the full Frak ecosystem:
```solidity
contract MyTest is EcosystemAwareTest {
    function setUp() public {
        _initEcosystemAwareTest();
        // Additional setup
    }
}
```

### Common Test Helpers
```solidity
vm.prank(address);           // Next call from address
vm.startPrank(address);      // All calls from address until stopPrank
vm.stopPrank();
vm.expectRevert(Error.selector);
vm.label(address, "name");   // Label address in traces
makeAddr("name");            // Create deterministic address
```

## Key Architectural Patterns

### Diamond Pattern (Custom)
`ProductInteractionDiamond` uses a custom diamond pattern:
- Facets per product type (Dapp, Press, WebShop, Retail)
- `delegatecall` to facets based on product type denominator
- Shared storage via `ProductInteractionStorageLib`

### Role-Based Access Control
Uses solady's `OwnableRoles`:
- Roles defined in `src/constants/Roles.sol`
- Product-specific roles via `ProductAdministratorRegistry`

### Deployment
Scripts in `script/` use CREATE2 with deterministic salts for consistent addresses across chains.

## Solhint Configuration
```json
{
  "extends": "solhint:recommended",
  "rules": {
    "no-inline-assembly": "off",
    "func-visibility": ["warn", {"ignoreConstructors": true}],
    "reason-string": "off",
    "gas-custom-errors": "off",
    "avoid-low-level-calls": "off"
  }
}
```

## Dependencies
- **bun**: Package manager (enforced via `preinstall` script)
- **Foundry**: Build, test, format
- **solhint**: Linting
- **@wagmi/cli**: ABI generation
