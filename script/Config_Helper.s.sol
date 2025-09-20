// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";

contract ConfigHelper is Script {
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 50000e8;
    int256 public constant SOL_USD_PRICE = 100e8;
    int256 public constant ADA_USD_PRICE = 1e8;

    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address wsolUsdPriceFeed;
        address wadaUsdPriceFeed;
        address weth;
        address wbtc;
        address wsol;
        address wada;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11_155_111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig()
        public
        view
        returns (NetworkConfig memory sepoliaNetworkConfig)
    {
        sepoliaNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            wsolUsdPriceFeed: 0x4ffC43a60e009B551865A93d232E33Fce9f01507, // SOL / USD
            wadaUsdPriceFeed: 0x882554df528115Af11c5b20E9899abc2e2E0f160, // ADA / USD on Sepolia
            weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            wsol: 0x2644980c2480eB8f31263D24189E2Aa5e7F8F1D3, // Wrapped SOL on Sepolia
            wada: 0x6Fc6A051d48AF3Ff95893Db45d4e497eE8F42B52, // Wrapped ADA on Sepolia (example address)
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig()
        public
        returns (NetworkConfig memory anvilNetworkConfig)
    {
        // Check to see if we set an active network config
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            ETH_USD_PRICE
        );
        ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, 1000e8);

        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            BTC_USD_PRICE
        );
        ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, 1000e8);

        MockV3Aggregator solUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            SOL_USD_PRICE
        );
        ERC20Mock wsolMock = new ERC20Mock("WSOL", "WSOL", msg.sender, 1000e8);

        MockV3Aggregator adaUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            ADA_USD_PRICE
        );
        ERC20Mock wadaMock = new ERC20Mock("WADA", "WADA", msg.sender, 1000e8);
        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: address(ethUsdPriceFeed), // ETH / USD
            wbtcUsdPriceFeed: address(btcUsdPriceFeed),
            wsolUsdPriceFeed: address(solUsdPriceFeed),
            wadaUsdPriceFeed: address(adaUsdPriceFeed),
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            wsol: address(wsolMock),
            wada: address(wadaMock),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}
