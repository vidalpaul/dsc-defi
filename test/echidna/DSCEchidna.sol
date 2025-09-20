// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {DSC} from "../../src/DSC.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";

/**
 * @title DSCEchidna
 * @author @vidalpaul
 * @notice Echidna property-based testing for DSC Protocol
 * @dev Contains invariants and properties for fuzzing with Echidna
 */
contract DSCEchidna {
    DSC public dsc;
    DSCEngine public dscEngine;
    
    ERC20Mock public weth;
    ERC20Mock public wbtc;
    MockV3Aggregator public ethUsdPriceFeed;
    MockV3Aggregator public btcUsdPriceFeed;
    
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;
    
    uint256 public constant INITIAL_BALANCE = 1000000e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant PRECISION = 1e18;
    
    constructor() {
        // Create mock tokens
        weth = new ERC20Mock("WETH", "WETH", address(this), INITIAL_BALANCE);
        wbtc = new ERC20Mock("WBTC", "WBTC", address(this), INITIAL_BALANCE);
        
        // Create mock price feeds
        ethUsdPriceFeed = new MockV3Aggregator(8, 2000e8); // $2000
        btcUsdPriceFeed = new MockV3Aggregator(8, 50000e8); // $50000
        
        // Setup arrays
        tokenAddresses = new address[](2);
        tokenAddresses[0] = address(weth);
        tokenAddresses[1] = address(wbtc);
        
        priceFeedAddresses = new address[](2);
        priceFeedAddresses[0] = address(ethUsdPriceFeed);
        priceFeedAddresses[1] = address(btcUsdPriceFeed);
        
        // Deploy DSC protocol
        dsc = new DSC();
        dscEngine = new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
        
        // Transfer ownership
        dsc.transferOwnership(address(dscEngine));
        
        // Approve tokens for the engine
        weth.approve(address(dscEngine), type(uint256).max);
        wbtc.approve(address(dscEngine), type(uint256).max);
    }
    
    ////////////////////
    // HELPER FUNCTIONS
    ////////////////////
    
    function _getRandomToken(uint256 seed) internal view returns (address) {
        return tokenAddresses[seed % tokenAddresses.length];
    }
    
    function _boundAmount(uint256 amount) internal pure returns (uint256) {
        return amount % 1000e18 + 1; // 1 to 1000 tokens
    }
    
    ////////////////////
    // PROTOCOL ACTIONS
    ////////////////////
    
    function depositCollateral(uint256 tokenSeed, uint256 amount) public {
        address token = _getRandomToken(tokenSeed);
        amount = _boundAmount(amount);
        
        // Ensure we have enough balance
        if (ERC20Mock(token).balanceOf(address(this)) < amount) {
            ERC20Mock(token).mint(address(this), amount);
            ERC20Mock(token).approve(address(dscEngine), amount);
        }
        
        dscEngine.depositCollateral(token, amount);
    }
    
    function mintDsc(uint256 amount) public {
        amount = _boundAmount(amount);
        
        // Only mint if health factor would remain above threshold
        uint256 collateralValue = dscEngine.getAccountCollateralValue(address(this));
        uint256 maxDscToMint = (collateralValue * LIQUIDATION_THRESHOLD) / 100 / PRECISION;
        
        if (amount <= maxDscToMint) {
            dscEngine.mintDSC(amount);
        }
    }
    
    function redeemCollateral(uint256 tokenSeed, uint256 amount) public {
        address token = _getRandomToken(tokenSeed);
        amount = _boundAmount(amount);
        
        uint256 collateralBalance = dscEngine.getCollateralBalanceOfUser(address(this), token);
        if (collateralBalance > 0 && amount <= collateralBalance) {
            dscEngine.redeemCollateral(token, amount);
        }
    }
    
    function burnDsc(uint256 amount) public {
        amount = _boundAmount(amount);
        
        uint256 dscBalance = dsc.balanceOf(address(this));
        if (dscBalance > 0 && amount <= dscBalance) {
            dscEngine.burnDSC(amount);
        }
    }
    
    ////////////////////
    // INVARIANTS
    ////////////////////
    
    /**
     * @notice Protocol should always be overcollateralized
     * @dev The total value of collateral should always exceed the total DSC minted
     */
    function echidna_protocol_is_overcollateralized() public view returns (bool) {
        uint256 totalSupply = dsc.totalSupply();
        if (totalSupply == 0) return true;
        
        uint256 totalCollateralValue = 0;
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            address token = tokenAddresses[i];
            uint256 tokenBalance = ERC20Mock(token).balanceOf(address(dscEngine));
            uint256 tokenValue = dscEngine.getUSDValue(token, tokenBalance);
            totalCollateralValue += tokenValue;
        }
        
        return totalCollateralValue >= totalSupply;
    }
    
    /**
     * @notice User's health factor should never be below minimum (except during liquidation)
     * @dev This ensures the protocol maintains proper collateralization
     */
    function echidna_health_factor_not_broken() public view returns (bool) {
        uint256 healthFactor = dscEngine.getHealthFactor(address(this));
        return healthFactor >= MIN_HEALTH_FACTOR || healthFactor == type(uint256).max;
    }
    
    /**
     * @notice DSC total supply should never exceed total collateral value
     * @dev This is a fundamental invariant of the stablecoin protocol
     */
    function echidna_dsc_supply_not_exceeding_collateral() public view returns (bool) {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalCollateralValue = 0;
        
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            address token = tokenAddresses[i];
            uint256 tokenBalance = ERC20Mock(token).balanceOf(address(dscEngine));
            uint256 tokenValue = dscEngine.getUSDValue(token, tokenBalance);
            totalCollateralValue += tokenValue;
        }
        
        return totalSupply <= totalCollateralValue;
    }
    
    /**
     * @notice User's collateral balance should always match engine's records
     * @dev Ensures no accounting errors in collateral tracking
     */
    function echidna_collateral_accounting_correct() public view returns (bool) {
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            address token = tokenAddresses[i];
            uint256 userCollateral = dscEngine.getCollateralBalanceOfUser(address(this), token);
            uint256 totalDeposited = ERC20Mock(token).balanceOf(address(dscEngine));
            
            // User's collateral should not exceed total deposited
            if (userCollateral > totalDeposited) {
                return false;
            }
        }
        return true;
    }
    
    /**
     * @notice DSC minted by user should match engine's records
     * @dev Ensures no accounting errors in DSC tracking
     */
    function echidna_dsc_accounting_correct() public view returns (bool) {
        uint256 userDscMinted = dscEngine.getDSCMinted(address(this));
        uint256 userDscBalance = dsc.balanceOf(address(this));
        
        // User's minted DSC should be at least their current balance
        return userDscMinted >= userDscBalance;
    }
    
    /**
     * @notice Price feed values should be reasonable
     * @dev Ensures price feed manipulation doesn't break the protocol
     */
    function echidna_price_feeds_reasonable() public view returns (bool) {
        (, int256 ethPrice,,,) = ethUsdPriceFeed.latestRoundData();
        (, int256 btcPrice,,,) = btcUsdPriceFeed.latestRoundData();
        
        // Prices should be positive and within reasonable bounds
        return ethPrice > 100e8 && ethPrice < 10000e8 && // $100 - $10,000
               btcPrice > 1000e8 && btcPrice < 200000e8;  // $1,000 - $200,000
    }
    
    /**
     * @notice Engine should always own the DSC contract
     * @dev Critical security invariant
     */
    function echidna_engine_owns_dsc() public view returns (bool) {
        return dsc.owner() == address(dscEngine);
    }
    
    /**
     * @notice Liquidation threshold should remain constant
     * @dev Protocol parameters should not change unexpectedly
     */
    function echidna_liquidation_threshold_constant() public view returns (bool) {
        return dscEngine.getLiquidationThreshold() == LIQUIDATION_THRESHOLD;
    }
}