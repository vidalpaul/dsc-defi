// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {DSC} from "../../src/DSC.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";

import {ConfigHelper} from "../../script/Config_Helper.s.sol";
import {DSC_Protocol_DeployScript} from "../../script/DSC_Protocol_Deploy.s.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

/**
 * @title DSCEngine_Unit_Test
 * @author @vidalpaul
 * @notice Unit test suite for DSCEngine contract
 * @dev Tests DSC engine functionality including collateral management and liquidations
 */
contract DSCEngine_Unit_Test is Test {
    DSC_Protocol_DeployScript public deployer;
    ConfigHelper public config;
    DSC public dsc;
    DSCEngine public dscEngine;

    address public constant USER_ALICE = address(0x1);
    address public constant USER_BOB = address(0x2);

    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    address public weth;
    address public wbtc;
    address public wsol;

    function setUp() public {
        deployer = new DSC_Protocol_DeployScript();
        deployer.setTestMode(true);
        (dsc, dscEngine, config) = deployer.run();

        (,,, weth, wbtc, wsol,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER_ALICE, STARTING_ERC20_BALANCE);
        ERC20Mock(wbtc).mint(USER_ALICE, STARTING_ERC20_BALANCE);
        ERC20Mock(wsol).mint(USER_ALICE, STARTING_ERC20_BALANCE);
    }
}
