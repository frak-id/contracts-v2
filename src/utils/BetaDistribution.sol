// SPDX-License-Identifier: GNU GPLv3
pragma solidity ^0.8.23;

import {console} from "forge-std/Console.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {LibPRNG} from "solady/utils/LibPRNG.sol";

/// @author @KONFeature
/// @title BetaDistribution
/// @notice A library to sample points from a Beta(2,β) probability distribution
/// (https://en.wikipedia.org/wiki/Beta_distribution)
/// @dev Implements two sampling methods for the Beta distribution with fixed α=2:
///
/// The Beta(2,β) distribution is a continuous probability distribution defined on [0,1]
/// that produces different shapes based on its β parameter:
///  - When β > 2: distribution is skewed towards 0
///  - When β = 2: distribution is symmetric (uniform)
///  - When β < 2: distribution is skewed towards 1
///
/// Mathematical foundation:
/// Uses the relationship between Beta and Gamma distributions:
/// If X ~ Gamma(α) and Y ~ Gamma(β), then X/(X+Y) ~ Beta(α,β)
///
/// Implementation features:
/// - Uses exponential sampling for integer β values
/// - Implements linear interpolation for decimal β values
/// - All calculations use WAD (1e18) fixed-point arithmetic
/// - Pseudo-random generation through LibPRNG
library BetaDistribution {
    using FixedPointMathLib for uint256;
    using LibPRNG for LibPRNG.PRNG;

    error InvalidBetaValue();
    error PointCalculationFailed();

    /// The fixed alpha parameter of the beta distribution
    uint256 internal constant WAD = 1e18;

    /// Maximum number of retries for the rejection sampling
    uint256 internal constant MAX_RETRIES = 100;

    /// @notice Generates a random point following a Beta(2,β) distribution for integer β values
    /// @dev Implements the relationship between Beta and Gamma distributions:
    /// Beta(2,β) = Gamma(2) / (Gamma(2) + Gamma(β))
    ///
    /// Where:
    /// - Gamma(2) = Exp(1) + Exp(1)  [sum of two exponential variables]
    /// - Gamma(β) = Σ(Exp(1)) β times [sum of β exponential variables]
    ///
    /// Properties:
    /// - When β > 2: points are skewed towards 0
    /// - When β = 2: points are symmetrically distributed
    /// - When β < 2: points are skewed towards 1
    ///
    /// @param beta The integer β parameter
    /// @return x A random point between 0 and 1 (in WAD) following Beta(2,β) distribution
    function getBetaIntegerPoint(uint256 beta) internal view returns (uint256 x) {
        // Ensure beta is a valid value
        if (beta == 0) {
            revert InvalidBetaValue();
        }

        // Initialize our PRNG with a random seed based on various chain parameters
        LibPRNG.PRNG memory prng = _initPrngSeed();

        // Return X = gammaAlpha / (gammaAlpha + gammaBeta)
        return _getPoint(prng, beta);
    }

    /// @notice Generates a random point following a Beta(2,β) distribution for any decimal β value
    /// @dev Uses linear interpolation between integer β values:
    /// For β = n.f (where n is integer part and f is fractional part):
    /// result = (1-f) * Beta(2,n) + f * Beta(2,n+1)
    ///
    /// Example for β = 3.7:
    /// 1. Calculate point₁ using β = 3
    /// 2. Calculate point₂ using β = 4
    /// 3. Return: point₁ * 0.3 + point₂ * 0.7
    ///
    /// @param wadBeta The β parameter in WAD format (1e18 precision)
    /// @return x A random point between 0 and 1 (in WAD) following Beta(2,β) distribution
    function getBetaWadPoint(uint256 wadBeta) internal view returns (uint256 x) {
        // Ensure beta is a valid value
        if (wadBeta == 0) {
            revert InvalidBetaValue();
        }

        // Initialize PRNG
        LibPRNG.PRNG memory prng = _initPrngSeed();

        // Calculate fractional part in WAD
        uint256 fraction = wadBeta % WAD;
        uint256 betaFloor = wadBeta / WAD; // floor(β)

        // If we got no fractional part, we can just return as an integer point
        if (fraction == 0) {
            return getBetaIntegerPoint(betaFloor);
        }

        // We can "safely" use an unchecked block here since `_getPoint` return safe values and  `divWad` do a check
        unchecked {
            // Get integer bounds of beta
            uint256 betaCeil = betaFloor + 1; // ceil(β)

            // Generate first sample with floor(β)
            uint256 point1 = _getPoint(prng, betaFloor);

            // Generate second sample with ceil(β)
            uint256 point2 = _getPoint(prng, betaCeil);

            // Interpolate between the two points
            // result = point1 * (1-fraction) + point2 * fraction
            return point1.mulWad(WAD - fraction) + point2.mulWad(fraction);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                   Helpers                                  */
    /* -------------------------------------------------------------------------- */

    function _initPrngSeed() internal view returns (LibPRNG.PRNG memory) {
        uint256 seed;
        assembly {
            let freeMemPtr := mload(0x40)
            mstore(0, gas())
            mstore(0x20, prevrandao())
            mstore(0x40, caller())
            seed := keccak256(0, 0x60)
            mstore(0x40, freeMemPtr)
        }
        // Initialize our PRNG with a random seed based on various chain parameters
        return LibPRNG.PRNG({state: seed});
    }

    /// @dev Helper function to get a beta-distributed point for integer beta values
    function _getPoint(LibPRNG.PRNG memory prng, uint256 beta) internal pure returns (uint256 point) {
        // We can "safely" use an unchecked block here since `exponentialWad` return safe values and  `divWad` do a
        // check
        unchecked {
            // For alpha=2, we need sum of two exponential samples
            // equivalent of: Gamma(2) = Exp(1) + Exp(1)
            uint256 gammaAlpha = prng.exponentialWad() + prng.exponentialWad();

            // For beta, use the sum of beta exponential samples
            // equivalent of: Gamma(β) = Σ(Exp(1)) β times
            uint256 gammaBeta;
            for (uint256 i = 0; i < beta; i++) {
                gammaBeta += prng.exponentialWad();
            }

            // Return X = gammaAlpha / (gammaAlpha + gammaBeta)
            point = gammaAlpha.divWad(gammaAlpha + gammaBeta);
            // Failsafe check
            if (point > WAD) {
                revert PointCalculationFailed();
            }
        }
    }
}
