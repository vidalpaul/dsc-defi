// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {DSC} from "../src/DSC.sol";
import {DSCEngine} from "../src/DSCEngine.sol";

import {ConfigHelper} from "./Config_Helper.s.sol";

contract DSC_Protocol_DeployScript is Script {
    DSC public dsc;
    DSCEngine public dscEngine;

    ConfigHelper public configHelper;
    
    bool public isTestMode;

    function setUp() public {}
    
    function setTestMode(bool _isTestMode) external {
        isTestMode = _isTestMode;
    }

    function run() external returns (DSC, DSCEngine, ConfigHelper) {
        if (!isTestMode) {
            vm.startBroadcast();
        }

        configHelper = new ConfigHelper();

        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address wsolUsdPriceFeed,
            address weth,
            address wbtc,
            address wsol,
            uint256 deployerKey
        ) = configHelper.activeNetworkConfig();

        address[] memory tokenAddresses = new address[](3);
        tokenAddresses[0] = weth;
        tokenAddresses[1] = wbtc;
        tokenAddresses[2] = wsol;

        address[] memory priceFeedAddresses = new address[](3);
        priceFeedAddresses[0] = wethUsdPriceFeed;
        priceFeedAddresses[1] = wbtcUsdPriceFeed;
        priceFeedAddresses[2] = wsolUsdPriceFeed;

        dsc = new DSC();

        dscEngine = new DSCEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(dsc)
        );

        dsc.transferOwnership(address(dscEngine));

        if (!isTestMode) {
            vm.stopBroadcast();
        }

        return (dsc, dscEngine, configHelper);
    }
}
