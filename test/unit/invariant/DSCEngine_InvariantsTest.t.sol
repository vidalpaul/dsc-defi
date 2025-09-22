// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

import {DSC} from "../../../src/DSC.sol";
import {DSCEngine} from "../../../src/DSCEngine.sol";

import {ConfigHelper} from "../../../script/Config_Helper.s.sol";
import {DSC_Protocol_DeployScript} from "../../../script/DSC_Protocol_Deploy.s.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
import {Handler} from "./Handler.t.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
    Handler public handler;
    address weth;
    address wbtc;
    address wsol;

    function setUp() external {
        deployer = new DSC_Protocol_DeployScript();
        deployer.setTestMode(true);
        (dsc, dscEngine, config) = deployer.run();

        (,,, weth, wbtc, wsol,) = config.activeNetworkConfig();

        handler = new Handler(dscEngine, dsc);

        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscEngine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));
        uint256 totalWsolDeposited = IERC20(wsol).balanceOf(address(dscEngine));

        uint256 wethValue = dscEngine.getUSDValue(weth, totalWethDeposited);
        uint256 wbtcValue = dscEngine.getUSDValue(wbtc, totalWbtcDeposited);
        uint256 wsolValue = dscEngine.getUSDValue(wsol, totalWsolDeposited);

        uint256 totalFromTokens = wethValue + wbtcValue + wsolValue;

        console.log("Mint was called ", handler.mintDSCCallsCounter(), " times");

        if (totalFromTokens > 0) {
            console.log("totalFromTokens: ", totalFromTokens);
            console.log("totalSuply: ", totalSupply);
            assert(totalFromTokens > totalSupply);
        }
    }

    function invariant_gettersShouldNotRevert() public view {
        dscEngine.getDSCMinted(address(this));
        dscEngine.getCollateralTokens();
        dscEngine.getDSCAddress();
        dscEngine.getMinHealthFactor();
        dscEngine.getLiquidationThreshold();
        dscEngine.getLiquidationBonus();

        dsc.totalSupply();
        dsc.balanceOf(address(this));
        dsc.name();
        dsc.symbol();
        dsc.decimals();
        dsc.owner();
    }
}
