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
import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// 1. The total supply of DSC should be less than the total value of collateral
// 2. Getter view functions should never revert <- evergreen invariant
// 3. Undercollateralized debtors should always be liquidateable
// 4. Healthy debtors should never be liquidated
// 5. Mapped collateral tokens should always be accepted
// 6. Unmapped collateral tokens should never be accepted
// 7. Mapped collateral tokens should nove be unlisted if at least a single healthy debtor has any amount of it deposited

contract Handler is StdInvariant, Test {
    DSC_Protocol_DeployScript public deployer;
    ConfigHelper public config;
    DSC public dsc;
    DSCEngine public dscEngine;
    ERC20Mock weth;
    ERC20Mock wbtc;
    ERC20Mock wsol;
    MockV3Aggregator public wethUSDPriceFeed;

    uint256 public mintDSCCallsCounter;
    address[] public usersWithCollateralDeposited;

    constructor(DSCEngine _dscEngine, DSC _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
        wsol = ERC20Mock(collateralTokens[2]);

        wethUSDPriceFeed = MockV3Aggregator(dscEngine.getPriceFeed(address(weth)));
    }

    function depositCollateral(uint256 _collateralSeed, uint256 _amountCollateral) public {
        ERC20Mock collateralToken = _getCollateralTokenFromSeed(_collateralSeed);
        uint256 amountCollateral = _getUint96MoreThanZero(_amountCollateral);

        vm.startPrank(msg.sender);

        collateralToken.mint(msg.sender, amountCollateral);
        collateralToken.approve(address(dscEngine), amountCollateral);

        dscEngine.depositCollateral(address(collateralToken), amountCollateral);

        vm.stopPrank();

        usersWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(uint256 _collateralSeed, uint256 _amountCollateral) public {
        ERC20Mock collateralToken = _getCollateralTokenFromSeed(_collateralSeed);
        uint256 maxCollateralToRedeem = dscEngine.getCollateralBalanceOfUser(msg.sender, address(collateralToken));

        uint256 amountCollateral = bound(_amountCollateral, 0, maxCollateralToRedeem);

        if (amountCollateral == 0) {
            return;
        }

        vm.startPrank(msg.sender);

        dscEngine.redeemCollateral(address(collateralToken), amountCollateral);

        vm.stopPrank();
    }

    /* ignore for now
    function updateCollateralPrice(uint96 _newPrice) public {
        int256 price = int256(uint256(_newPrice));
        wethUSDPriceFeed.updateAnswer(price);
    } 
    */

    function mintDSC(uint256 _amount, uint256 _addressSeed) public {
        if (usersWithCollateralDeposited.length == 0) {
            return;
        }

        address sender = usersWithCollateralDeposited[_addressSeed % usersWithCollateralDeposited.length];

        vm.startPrank(sender);

        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = dscEngine.getAccountInformation(sender);

        int256 maxDSCToMint = (int256(collateralValueInUSD) / 2 - int256(totalDSCMinted));

        if (maxDSCToMint < 0) {
            return;
        }

        uint256 amount = bound(_amount, 0, uint256(maxDSCToMint));

        if (amount == 0) {
            return;
        }

        dscEngine.mintDSC(amount);
        vm.stopPrank();

        mintDSCCallsCounter++;
    }

    function _getUint96MoreThanZero(uint256 amountSeed) private pure returns (uint256 amount) {
        amount = bound(amountSeed, 1, type(uint96).max);
    }

    function _getCollateralTokenFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 3 == 0) {
            return weth;
        }
        if (collateralSeed % 3 == 1) {
            return wbtc;
        } else {
            return wsol;
        }
    }
}
