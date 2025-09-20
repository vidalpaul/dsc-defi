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

    function setUp() public {}

    function run() external returns (DSC, DSCEngine) {
        vm.startBroadcast();

        configHelper = new ConfigHelper();

        (
            address wethUsdPriceFeed,
            address wbtcUsdPriceFeed,
            address wsolUsdPriceFeed,
            address wadaUsdPriceFeed,
            address weth,
            address wbtc,
            address wsol,
            // address wada,
            uint256 deployerKey
        ) = configHelper.activeNetworkConfig();

        address[] memory tokenAddresses = new address[](4);
        tokenAddresses[0] = weth;
        tokenAddresses[1] = wbtc;
        tokenAddresses[2] = wsol;
        // tokenAddresses[3] = wada;

        address[] memory priceFeedAddresses = new address[](4);
        priceFeedAddresses[0] = wethUsdPriceFeed;
        priceFeedAddresses[1] = wbtcUsdPriceFeed;
        priceFeedAddresses[2] = wsolUsdPriceFeed;
        // priceFeedAddresses[3] = wadaUsdPriceFeed;

        dsc = new DSC();

        dscEngine = new DSCEngine(
            tokenAddresses,
            priceFeedAddresses,
            address(dsc)
        );

        dsc.transferownership(address(dscEngine));

        vm.stopBroadcast();

        return (dsc, dscEngine);
    }
}
