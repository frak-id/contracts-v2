// SPDX-License-Identifier: GNU GPLv3
pragma solidity 0.8.23;

import {console} from "forge-std/Console.sol";
import {Test} from "forge-std/Test.sol";

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {LibPRNG} from "solady/utils/LibPRNG.sol";
import {BetaDistribution} from "src/utils/BetaDistribution.sol";

contract BetaDistributionTest is Test {
    /* -------------------------------------------------------------------------- */
    /*                              Integer beta test                             */
    /* -------------------------------------------------------------------------- */

    /// Test the generation of a single point on the alpha = 2 and beta = 10 curve
    function test_integerBetaPoint_betaSuperior() public view {
        uint256 point = BetaDistribution.getBetaIntegerPoint(10);
        assertGt(point, 0, "Point should be greater than 0");
        assertLt(point, FixedPointMathLib.WAD, "Point should be lower than WAD");
    }

    /// Test the generation of a single point on the alpha = 2 and beta = 10 curve
    function test_integerBetaPoint_betaEqual() public view {
        uint256 point = BetaDistribution.getBetaIntegerPoint(2);
        assertGt(point, 0, "Point should be greater than 0");
        assertLt(point, FixedPointMathLib.WAD, "Point should be lower than WAD");
    }

    /// Test the generation of a single point on the alpha = 2 and beta = 10 curve
    function test_integerBetaPoint_betaInferior() public view {
        uint256 point = BetaDistribution.getBetaIntegerPoint(1);
        assertGt(point, 0, "Point should be greater than 0");
        assertLt(point, FixedPointMathLib.WAD, "Point should be lower than WAD");
    }

    // Enure every runs generate new points on the curve
    function test_integerBetaPoint_differentPoints() public view {
        uint256 betaWad = 10;

        uint256 p1 = BetaDistribution.getBetaIntegerPoint(betaWad);
        uint256 p2 = BetaDistribution.getBetaIntegerPoint(betaWad);
        uint256 p3 = BetaDistribution.getBetaIntegerPoint(betaWad);

        assertNotEq(p1, p2);
        assertNotEq(p2, p3);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Wad beta test                               */
    /* -------------------------------------------------------------------------- */

    /// Test the generation of a single point on the alpha = 2 and beta = 10 curve
    function test_wadBetaPoint_betaSuperior() public view {
        uint256 point = BetaDistribution.getBetaWadPoint(13.12e18);
        assertGt(point, 0, "Point should be greater than 0");
        assertLt(point, FixedPointMathLib.WAD, "Point should be lower than WAD");
    }

    /// Test the generation of a single point on the alpha = 2 and beta = 10 curve
    function test_wadBetaPoint_betaEqual() public view {
        uint256 point = BetaDistribution.getBetaWadPoint(2.12e18);
        assertGt(point, 0, "Point should be greater than 0");
        assertLt(point, FixedPointMathLib.WAD, "Point should be lower than WAD");
    }

    /// Test the generation of a single point on the alpha = 2 and beta = 10 curve
    function test_wadBetaPoint_betaInferior() public view {
        uint256 point = BetaDistribution.getBetaWadPoint(0.85e18);
        assertGt(point, 0, "Point should be greater than 0");
        assertLt(point, FixedPointMathLib.WAD, "Point should be lower than WAD");
    }

    // Enure every runs generate new points on the curve
    function test_wadBetaPoint_differentPoints() public view {
        uint256 betaWad = 10.85e18;

        uint256 p1 = BetaDistribution.getBetaWadPoint(betaWad);
        uint256 p2 = BetaDistribution.getBetaWadPoint(betaWad);
        uint256 p3 = BetaDistribution.getBetaWadPoint(betaWad);

        assertNotEq(p1, p2);
        assertNotEq(p2, p3);
    }

    // Generate 10_000 points and write that to a CSV, to ensure it righly follows the beta distribution
    function test_wadBetaPoint_distribution() public {
        vm.skip(true);
        uint256 betaWad = 13.12e18;
        uint256 runs = 50_000;
        uint256[] memory points = new uint256[](50_000);

        for (uint256 i = 0; i < runs; i++) {
            points[i] = BetaDistribution.getBetaWadPoint(betaWad);
        }

        // Write to CSV
        console.log("x");
        for (uint256 i = 0; i < runs; i++) {
            console.log(points[i]);
        }
    }
}
