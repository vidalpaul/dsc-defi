// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {DSC} from "../../../src/DSC.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";

import {ConfigHelper} from "../../../script/Config_Helper.s.sol";
import {DSC_Protocol_DeployScript} from "../../../script/DSC_Protocol_Deploy.s.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";

// 1. The total supply of DSC should be less than the total value of collateral
// 2. Getter view functions should never revert <- evergreen invariant
// 3. Undercollateralized debtors should always be liquidateable
// 4. Healthy debtors should never be liquidated
// 5. Mapped collateral tokens should always be accepted
// 6. Unmapped collateral tokens should never be accepted
// 7. Mapped collateral tokens should nove be unlisted if at least a single healthy debtor has any amount of it deposited

contract InvariantsTest is StdInvariant, Test {
    DSC_Protocol_DeployScript public deployer;
    ConfigHelper public config;
    DSC public dsc;
    DSCEngine public dscEngine;

    function setUp() external {
        deployer = new DSC_Protocol_DeployScript();
        deployer.setTestMode(true);
        (dsc, dscEngine, config) = deployer.run();
    }
}
