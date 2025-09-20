// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title DSCLib
 * @author @vidalpaul
 * @notice Library containing common utility functions for the DSC protocol
 * @dev Contains reusable validation, calculation, and helper functions
 */
library DSCLib {
    // =============================================================
    //                       ERRORS
    // =============================================================
    error DSCLib_AmountMustBeGreaterThanZero();
    error DSCLib_AddressCannotBeZero();
    error DSCLib_TransferFailed();

    // =============================================================
    //                       CONSTANTS
    // =============================================================
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant FEED_PRECISION = 1e8;

    // =============================================================
    //                       VALIDATION FUNCTIONS
    // =============================================================

    /**
     * @notice Validates that an amount is greater than zero
     * @param _amount The amount to validate
     */
    function validateAmountGreaterThanZero(uint256 _amount) internal pure {
        require(_amount > 0, DSCLib_AmountMustBeGreaterThanZero());
    }

    /**
     * @notice Validates that an address is not the zero address
     * @param _address The address to validate
     */
    function validateAddressNotZero(address _address) internal pure {
        require(_address != address(0), DSCLib_AddressCannotBeZero());
    }

    // =============================================================
    //                       PRICE FEED FUNCTIONS
    // =============================================================

    /**
     * @notice Gets the latest price from a Chainlink price feed
     * @param _priceFeed The address of the Chainlink price feed
     * @return price The latest price from the feed
     */
    function getLatestPrice(address _priceFeed) internal view returns (uint256 price) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeed);
        (, int256 priceInt,,,) = priceFeed.latestRoundData();
        return uint256(priceInt);
    }

    /**
     * @notice Converts token amount to USD value using price feed
     * @param _priceFeed The address of the Chainlink price feed
     * @param _amount The amount of tokens to convert
     * @return usdValue The USD value of the token amount
     */
    function getUSDValue(address _priceFeed, uint256 _amount) internal view returns (uint256 usdValue) {
        uint256 price = getLatestPrice(_priceFeed);
        return ((price * ADDITIONAL_FEED_PRECISION) * _amount) / 1e18;
    }

    /**
     * @notice Converts USD amount to token amount using price feed
     * @param _priceFeed The address of the Chainlink price feed
     * @param _usdAmountInWei The USD amount in wei (18 decimals)
     * @return tokenAmount The equivalent amount in tokens
     */
    function getTokenAmountFromUSD(address _priceFeed, uint256 _usdAmountInWei)
        internal
        view
        returns (uint256 tokenAmount)
    {
        uint256 price = getLatestPrice(_priceFeed);
        return (_usdAmountInWei * PRECISION) / (price * ADDITIONAL_FEED_PRECISION);
    }

    // =============================================================
    //                       TRANSFER FUNCTIONS
    // =============================================================

    /**
     * @notice Safely transfers ERC20 tokens and reverts on failure
     * @param _token The ERC20 token address
     * @param _to The recipient address
     * @param _amount The amount to transfer
     */
    function safeTransfer(address _token, address _to, uint256 _amount) internal {
        bool success = IERC20(_token).transfer(_to, _amount);
        require(success, DSCLib_TransferFailed());
    }

    /**
     * @notice Safely transfers ERC20 tokens from one address to another and reverts on failure
     * @param _token The ERC20 token address
     * @param _from The sender address
     * @param _to The recipient address
     * @param _amount The amount to transfer
     */
    function safeTransferFrom(address _token, address _from, address _to, uint256 _amount) internal {
        bool success = IERC20(_token).transferFrom(_from, _to, _amount);
        require(success, DSCLib_TransferFailed());
    }

    // =============================================================
    //                       CALCULATION FUNCTIONS
    // =============================================================

    /**
     * @notice Calculates health factor from DSC minted and collateral value
     * @param _totalDSCMinted The total amount of DSC tokens minted
     * @param _collateralValueInUsd The total USD value of collateral
     * @param _liquidationThreshold The liquidation threshold percentage
     * @return healthFactor The calculated health factor
     */
    function calculateHealthFactor(
        uint256 _totalDSCMinted,
        uint256 _collateralValueInUsd,
        uint256 _liquidationThreshold
    ) internal pure returns (uint256 healthFactor) {
        if (_totalDSCMinted == 0) {
            return type(uint256).max;
        }

        uint256 liquidationPrecision = 100;
        uint256 collateralAdjustedForThreshold = (_collateralValueInUsd * _liquidationThreshold) / liquidationPrecision;
        return (collateralAdjustedForThreshold * PRECISION) / _totalDSCMinted;
    }

    // =============================================================
    //                       GETTER FUNCTIONS
    // =============================================================

    /**
     * @notice Gets the precision constant used in calculations
     * @return The precision constant (1e18)
     */
    function getPrecision() internal pure returns (uint256) {
        return PRECISION;
    }

    /**
     * @notice Gets the additional feed precision constant
     * @return The additional feed precision constant (1e10)
     */
    function getAdditionalFeedPrecision() internal pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    /**
     * @notice Gets the feed precision constant
     * @return The feed precision constant (1e8)
     */
    function getFeedPrecision() internal pure returns (uint256) {
        return FEED_PRECISION;
    }
}
