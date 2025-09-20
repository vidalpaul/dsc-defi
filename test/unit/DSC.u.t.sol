// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {DSC} from "../../src/DSC.sol";

contract DSC_Unit_Test is Test {
    DSC public dsc;

    function setUp() public {
        dsc = new DSC();
    }
}
