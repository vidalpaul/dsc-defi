// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";

contract DSCEngine_Unit_Test is Test {
    DSCEngine public dscEngine;

    function setUp() public {
        dscEngine = new DSCEngine();
    }
}
