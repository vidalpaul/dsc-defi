// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {DSC} from "../../src/DSC.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";

import {DSC_Protocol_DeployScript} from "../../script/DSC_Protocol_Deploy.s.sol";

/**
 * @title DSC_Unit_Test
 * @author @vidalpaul
 * @notice Comprehensive unit test suite for DSC (Decentralized Stable Coin) contract
 * @dev Tests all DSC functionality including minting, burning, transfers, and ownership
 */
contract DSC_Unit_Test is Test {
    DSC_Protocol_DeployScript public deployer;
    DSC public dsc;
    DSCEngine public dscEngine;

    address public constant USER_ALICE = address(2);
    address public constant USER_BOB = address(3);
    address public constant ZERO_ADDRESS = address(0);

    uint256 public constant MINT_AMOUNT = 100e18;
    uint256 public constant BURN_AMOUNT = 50e18;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public {
        deployer = new DSC_Protocol_DeployScript();
        deployer.setTestMode(true);
        (dsc, dscEngine,) = deployer.run();
    }

    /////////////////////
    // Constructor Tests
    /////////////////////

    function test_Constructor_SetsCorrectNameAndSymbol() public view {
        assertEq(dsc.name(), "DSC");
        assertEq(dsc.symbol(), "DSC");
    }

    function test_Constructor_SetsCorrectDecimals() public view {
        assertEq(dsc.decimals(), 18);
    }

    function test_Constructor_InitialSupplyIsZero() public view {
        assertEq(dsc.totalSupply(), 0);
    }

    function test_Constructor_OwnerIsEngine() public view {
        assertEq(dsc.owner(), address(dscEngine));
    }

    /////////////////////
    // Mint Function Tests
    /////////////////////

    function test_Mint_Success() public {
        vm.prank(address(dscEngine));
        bool success = dsc.mint(USER_ALICE, MINT_AMOUNT);

        assertTrue(success);
        assertEq(dsc.balanceOf(USER_ALICE), MINT_AMOUNT);
        assertEq(dsc.totalSupply(), MINT_AMOUNT);
    }

    function test_Mint_EmitsTransferEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), USER_ALICE, MINT_AMOUNT);

        vm.prank(address(dscEngine));
        dsc.mint(USER_ALICE, MINT_AMOUNT);
    }

    function test_Mint_MultipleMints() public {
        vm.startPrank(address(dscEngine));
        dsc.mint(USER_ALICE, MINT_AMOUNT);
        dsc.mint(USER_BOB, MINT_AMOUNT * 2);
        vm.stopPrank();

        assertEq(dsc.balanceOf(USER_ALICE), MINT_AMOUNT);
        assertEq(dsc.balanceOf(USER_BOB), MINT_AMOUNT * 2);
        assertEq(dsc.totalSupply(), MINT_AMOUNT * 3);
    }

    function test_Mint_RevertsWhenCalledByNonOwner() public {
        vm.expectRevert();
        vm.prank(USER_ALICE);
        dsc.mint(USER_BOB, MINT_AMOUNT);
    }

    function test_Mint_RevertsWhenAmountIsZero() public {
        vm.expectRevert(DSC.DSC_Mint_AmountCannotBeZero.selector);
        vm.prank(address(dscEngine));
        dsc.mint(USER_ALICE, 0);
    }

    function test_Mint_RevertsWhenRecipientIsZeroAddress() public {
        vm.expectRevert(DSC.DSC_Mint_RecipientCannotBeZeroAddress.selector);
        vm.prank(address(dscEngine));
        dsc.mint(ZERO_ADDRESS, MINT_AMOUNT);
    }

    function test_Mint_LargeAmount() public {
        uint256 largeAmount = type(uint256).max / 2;
        vm.prank(address(dscEngine));
        dsc.mint(USER_ALICE, largeAmount);

        assertEq(dsc.balanceOf(USER_ALICE), largeAmount);
        assertEq(dsc.totalSupply(), largeAmount);
    }

    /////////////////////
    // Burn Function Tests
    /////////////////////

    function test_Burn_Success() public {
        vm.startPrank(address(dscEngine));
        dsc.mint(address(dscEngine), MINT_AMOUNT);
        dsc.burn(BURN_AMOUNT);
        vm.stopPrank();

        assertEq(dsc.balanceOf(address(dscEngine)), MINT_AMOUNT - BURN_AMOUNT);
        assertEq(dsc.totalSupply(), MINT_AMOUNT - BURN_AMOUNT);
    }

    function test_Burn_EmitsTransferEvent() public {
        vm.startPrank(address(dscEngine));
        dsc.mint(address(dscEngine), MINT_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(dscEngine), address(0), BURN_AMOUNT);
        dsc.burn(BURN_AMOUNT);
        vm.stopPrank();
    }

    function test_Burn_FullBalance() public {
        vm.startPrank(address(dscEngine));
        dsc.mint(address(dscEngine), MINT_AMOUNT);
        dsc.burn(MINT_AMOUNT);
        vm.stopPrank();

        assertEq(dsc.balanceOf(address(dscEngine)), 0);
        assertEq(dsc.totalSupply(), 0);
    }

    function test_Burn_MultipleBurns() public {
        vm.startPrank(address(dscEngine));
        dsc.mint(address(dscEngine), MINT_AMOUNT);
        dsc.burn(BURN_AMOUNT / 2);
        dsc.burn(BURN_AMOUNT / 2);
        vm.stopPrank();

        assertEq(dsc.balanceOf(address(dscEngine)), MINT_AMOUNT - BURN_AMOUNT);
        assertEq(dsc.totalSupply(), MINT_AMOUNT - BURN_AMOUNT);
    }

    function test_Burn_RevertsWhenCalledByNonOwner() public {
        vm.prank(address(dscEngine));
        dsc.mint(USER_ALICE, MINT_AMOUNT);

        vm.expectRevert();
        vm.prank(USER_ALICE);
        dsc.burn(BURN_AMOUNT);
    }

    function test_Burn_RevertsWhenAmountIsZero() public {
        vm.startPrank(address(dscEngine));
        dsc.mint(address(dscEngine), MINT_AMOUNT);

        vm.expectRevert(DSC.DSC_Burn_AmountCannotBeZero.selector);
        dsc.burn(0);
        vm.stopPrank();
    }

    function test_Burn_RevertsWhenAmountExceedsBalance() public {
        vm.startPrank(address(dscEngine));
        dsc.mint(address(dscEngine), MINT_AMOUNT);

        vm.expectRevert(DSC.DSC_Burn_AmountCannotBeMoreThanBalance.selector);
        dsc.burn(MINT_AMOUNT + 1);
        vm.stopPrank();
    }

    function test_Burn_RevertsWhenNoBalance() public {
        vm.expectRevert(DSC.DSC_Burn_AmountCannotBeMoreThanBalance.selector);
        vm.prank(address(dscEngine));
        dsc.burn(1);
    }

    /////////////////////
    // BurnFrom Function Tests (inherited from ERC20Burnable)
    /////////////////////

    function test_BurnFrom_Success() public {
        vm.prank(address(dscEngine));
        dsc.mint(USER_ALICE, MINT_AMOUNT);

        vm.prank(USER_ALICE);
        dsc.approve(USER_BOB, BURN_AMOUNT);

        vm.prank(USER_BOB);
        dsc.burnFrom(USER_ALICE, BURN_AMOUNT);

        assertEq(dsc.balanceOf(USER_ALICE), MINT_AMOUNT - BURN_AMOUNT);
        assertEq(dsc.totalSupply(), MINT_AMOUNT - BURN_AMOUNT);
        assertEq(dsc.allowance(USER_ALICE, USER_BOB), 0);
    }

    function test_BurnFrom_PartialAllowance() public {
        vm.prank(address(dscEngine));
        dsc.mint(USER_ALICE, MINT_AMOUNT);

        vm.prank(USER_ALICE);
        dsc.approve(USER_BOB, BURN_AMOUNT * 2);

        vm.prank(USER_BOB);
        dsc.burnFrom(USER_ALICE, BURN_AMOUNT);

        assertEq(dsc.allowance(USER_ALICE, USER_BOB), BURN_AMOUNT);
    }

    function test_BurnFrom_RevertsWhenInsufficientAllowance() public {
        vm.prank(address(dscEngine));
        dsc.mint(USER_ALICE, MINT_AMOUNT);

        vm.prank(USER_ALICE);
        dsc.approve(USER_BOB, BURN_AMOUNT - 1);

        vm.expectRevert();
        vm.prank(USER_BOB);
        dsc.burnFrom(USER_ALICE, BURN_AMOUNT);
    }

    /////////////////////
    // Transfer Function Tests
    /////////////////////

    function test_Transfer_Success() public {
        vm.prank(address(dscEngine));
        dsc.mint(USER_ALICE, MINT_AMOUNT);

        vm.prank(USER_ALICE);
        bool success = dsc.transfer(USER_BOB, BURN_AMOUNT);

        assertTrue(success);
        assertEq(dsc.balanceOf(USER_ALICE), MINT_AMOUNT - BURN_AMOUNT);
        assertEq(dsc.balanceOf(USER_BOB), BURN_AMOUNT);
    }

    function test_Transfer_EmitsEvent() public {
        vm.prank(address(dscEngine));
        dsc.mint(USER_ALICE, MINT_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit Transfer(USER_ALICE, USER_BOB, BURN_AMOUNT);

        vm.prank(USER_ALICE);
        dsc.transfer(USER_BOB, BURN_AMOUNT);
    }

    function test_Transfer_RevertsWhenInsufficientBalance() public {
        vm.prank(address(dscEngine));
        dsc.mint(USER_ALICE, MINT_AMOUNT);

        vm.expectRevert();
        vm.prank(USER_ALICE);
        dsc.transfer(USER_BOB, MINT_AMOUNT + 1);
    }

    /////////////////////
    // Approve and TransferFrom Tests
    /////////////////////

    function test_Approve_Success() public {
        vm.prank(address(dscEngine));
        dsc.mint(USER_ALICE, MINT_AMOUNT);

        vm.prank(USER_ALICE);
        bool success = dsc.approve(USER_BOB, MINT_AMOUNT);

        assertTrue(success);
        assertEq(dsc.allowance(USER_ALICE, USER_BOB), MINT_AMOUNT);
    }

    function test_Approve_EmitsEvent() public {
        vm.prank(address(dscEngine));
        dsc.mint(USER_ALICE, MINT_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit Approval(USER_ALICE, USER_BOB, MINT_AMOUNT);

        vm.prank(USER_ALICE);
        dsc.approve(USER_BOB, MINT_AMOUNT);
    }

    function test_TransferFrom_Success() public {
        vm.prank(address(dscEngine));
        dsc.mint(USER_ALICE, MINT_AMOUNT);

        vm.prank(USER_ALICE);
        dsc.approve(USER_BOB, MINT_AMOUNT);

        vm.prank(USER_BOB);
        bool success = dsc.transferFrom(USER_ALICE, address(dscEngine), BURN_AMOUNT);

        assertTrue(success);
        assertEq(dsc.balanceOf(USER_ALICE), MINT_AMOUNT - BURN_AMOUNT);
        assertEq(dsc.balanceOf(address(dscEngine)), BURN_AMOUNT);
        assertEq(dsc.allowance(USER_ALICE, USER_BOB), MINT_AMOUNT - BURN_AMOUNT);
    }

    function test_TransferFrom_RevertsWhenInsufficientAllowance() public {
        vm.prank(address(dscEngine));
        dsc.mint(USER_ALICE, MINT_AMOUNT);

        vm.prank(USER_ALICE);
        dsc.approve(USER_BOB, BURN_AMOUNT - 1);

        vm.expectRevert();
        vm.prank(USER_BOB);
        dsc.transferFrom(USER_ALICE, address(dscEngine), BURN_AMOUNT);
    }

    /////////////////////
    // Ownership Tests
    /////////////////////

    function test_TransferOwnership_Success() public {
        vm.prank(address(dscEngine));
        dsc.transferOwnership(USER_ALICE);

        assertEq(dsc.owner(), USER_ALICE);
    }

    function test_TransferOwnership_EmitsEvent() public {
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(dscEngine), USER_ALICE);

        vm.prank(address(dscEngine));
        dsc.transferOwnership(USER_ALICE);
    }

    function test_TransferOwnership_RevertsWhenCalledByNonOwner() public {
        vm.expectRevert();
        vm.prank(USER_ALICE);
        dsc.transferOwnership(USER_BOB);
    }

    function test_RenounceOwnership_Success() public {
        vm.prank(address(dscEngine));
        dsc.renounceOwnership();

        assertEq(dsc.owner(), address(0));
    }

    function test_RenounceOwnership_EmitsEvent() public {
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(address(dscEngine), address(0));

        vm.prank(address(dscEngine));
        dsc.renounceOwnership();
    }

    function test_RenounceOwnership_PreventsSubsequentMinting() public {
        vm.prank(address(dscEngine));
        dsc.renounceOwnership();

        vm.expectRevert();
        vm.prank(address(dscEngine));
        dsc.mint(USER_ALICE, MINT_AMOUNT);
    }

    /////////////////////
    // Edge Cases and Complex Scenarios
    /////////////////////

    function test_MintBurnCycle() public {
        vm.startPrank(address(dscEngine));

        dsc.mint(address(dscEngine), MINT_AMOUNT);
        assertEq(dsc.totalSupply(), MINT_AMOUNT);

        dsc.burn(BURN_AMOUNT);
        assertEq(dsc.totalSupply(), MINT_AMOUNT - BURN_AMOUNT);

        dsc.mint(address(dscEngine), BURN_AMOUNT);
        assertEq(dsc.totalSupply(), MINT_AMOUNT);

        dsc.burn(MINT_AMOUNT);
        assertEq(dsc.totalSupply(), 0);

        vm.stopPrank();
    }

    function test_ComplexTransferScenario() public {
        vm.prank(address(dscEngine));
        dsc.mint(USER_ALICE, MINT_AMOUNT);

        vm.prank(USER_ALICE);
        dsc.transfer(USER_BOB, BURN_AMOUNT);

        vm.prank(USER_BOB);
        dsc.transfer(address(dscEngine), BURN_AMOUNT / 2);

        assertEq(dsc.balanceOf(USER_ALICE), MINT_AMOUNT - BURN_AMOUNT);
        assertEq(dsc.balanceOf(USER_BOB), BURN_AMOUNT / 2);
        assertEq(dsc.balanceOf(address(dscEngine)), BURN_AMOUNT / 2);
        assertEq(dsc.totalSupply(), MINT_AMOUNT);
    }

    function test_MaxSupply() public {
        uint256 maxAmount = type(uint256).max;

        vm.prank(address(dscEngine));
        dsc.mint(USER_ALICE, maxAmount);

        assertEq(dsc.balanceOf(USER_ALICE), maxAmount);
        assertEq(dsc.totalSupply(), maxAmount);

        vm.expectRevert();
        vm.prank(address(dscEngine));
        dsc.mint(USER_BOB, 1);
    }
}
