// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "../../mocks/ERC20Mock.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/**
 * @title ERC20Mock_Unit_Test
 * @author @vidalpaul
 * @notice Comprehensive unit test suite for ERC20Mock contract
 * @dev Tests all ERC20Mock functionality including custom internal functions
 */
contract ERC20Mock_Unit_Test is Test {
    ERC20Mock public token;

    // Test accounts
    address public constant USER_ALICE = address(0x1);
    address public constant USER_BOB = address(0x2);
    address public constant USER_CHARLIE = address(0x3);

    // Test amounts
    uint256 public constant INITIAL_BALANCE = 1000e18;
    uint256 public constant MINT_AMOUNT = 500e18;
    uint256 public constant BURN_AMOUNT = 200e18;
    uint256 public constant TRANSFER_AMOUNT = 100e18;
    uint256 public constant APPROVE_AMOUNT = 300e18;

    // Test token details
    string public constant TOKEN_NAME = "Mock Token";
    string public constant TOKEN_SYMBOL = "MOCK";

    /**
     * @notice Sets up the test environment before each test
     * @dev Creates a new ERC20Mock with initial balance for USER_ALICE
     */
    function setUp() public {
        token = new ERC20Mock(TOKEN_NAME, TOKEN_SYMBOL, USER_ALICE, INITIAL_BALANCE);
    }

    ////////////////////////////////
    // Constructor Tests
    ////////////////////////////////

    /**
     * @notice Tests that constructor sets correct token name and symbol
     */
    function test_Constructor_SetsCorrectNameAndSymbol() public view {
        assertEq(token.name(), TOKEN_NAME, "Name should be set correctly");
        assertEq(token.symbol(), TOKEN_SYMBOL, "Symbol should be set correctly");
    }

    /**
     * @notice Tests that constructor sets correct decimals (18)
     */
    function test_Constructor_SetsCorrectDecimals() public view {
        assertEq(token.decimals(), 18, "Decimals should be 18");
    }

    /**
     * @notice Tests that constructor mints initial balance to specified account
     */
    function test_Constructor_MintsInitialBalance() public view {
        assertEq(token.balanceOf(USER_ALICE), INITIAL_BALANCE, "Initial balance should be minted to account");
        assertEq(token.totalSupply(), INITIAL_BALANCE, "Total supply should equal initial balance");
    }

    /**
     * @notice Tests that constructor works with zero initial balance
     */
    function test_Constructor_ZeroInitialBalance() public {
        ERC20Mock zeroToken = new ERC20Mock(TOKEN_NAME, TOKEN_SYMBOL, USER_BOB, 0);
        assertEq(zeroToken.balanceOf(USER_BOB), 0, "Zero initial balance should work");
        assertEq(zeroToken.totalSupply(), 0, "Total supply should be zero");
    }

    ////////////////////////////////
    // Mint Function Tests
    ////////////////////////////////

    function test_Mint_Success() public {
        uint256 initialBalance = token.balanceOf(USER_BOB);
        uint256 initialSupply = token.totalSupply();

        token.mint(USER_BOB, MINT_AMOUNT);

        assertEq(token.balanceOf(USER_BOB), initialBalance + MINT_AMOUNT, "Balance should increase");
        assertEq(token.totalSupply(), initialSupply + MINT_AMOUNT, "Total supply should increase");
    }

    function test_Mint_EmitsTransferEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(address(0), USER_BOB, MINT_AMOUNT);

        token.mint(USER_BOB, MINT_AMOUNT);
    }

    function test_Mint_ToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.mint(address(0), MINT_AMOUNT);
    }

    function test_Mint_ZeroAmount() public {
        uint256 initialBalance = token.balanceOf(USER_BOB);
        uint256 initialSupply = token.totalSupply();

        token.mint(USER_BOB, 0);

        assertEq(token.balanceOf(USER_BOB), initialBalance, "Balance should not change");
        assertEq(token.totalSupply(), initialSupply, "Total supply should not change");
    }

    function test_Mint_MultipleMints() public {
        token.mint(USER_BOB, MINT_AMOUNT);
        token.mint(USER_BOB, MINT_AMOUNT);

        assertEq(token.balanceOf(USER_BOB), MINT_AMOUNT * 2, "Multiple mints should accumulate");
    }

    function test_Mint_LargeAmount() public {
        uint256 largeAmount = type(uint128).max;
        token.mint(USER_BOB, largeAmount);

        assertEq(token.balanceOf(USER_BOB), largeAmount, "Should handle large amounts");
    }

    ////////////////////////////////
    // Burn Function Tests
    ////////////////////////////////

    function test_Burn_Success() public {
        // Setup: mint some tokens first
        token.mint(USER_BOB, MINT_AMOUNT);
        uint256 initialBalance = token.balanceOf(USER_BOB);
        uint256 initialSupply = token.totalSupply();

        token.burn(USER_BOB, BURN_AMOUNT);

        assertEq(token.balanceOf(USER_BOB), initialBalance - BURN_AMOUNT, "Balance should decrease");
        assertEq(token.totalSupply(), initialSupply - BURN_AMOUNT, "Total supply should decrease");
    }

    function test_Burn_EmitsTransferEvent() public {
        token.mint(USER_BOB, MINT_AMOUNT);

        vm.expectEmit(true, true, false, true);
        emit Transfer(USER_BOB, address(0), BURN_AMOUNT);

        token.burn(USER_BOB, BURN_AMOUNT);
    }

    function test_Burn_InsufficientBalance() public {
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, USER_BOB, 0, BURN_AMOUNT)
        );
        token.burn(USER_BOB, BURN_AMOUNT);
    }

    function test_Burn_FromZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(0)));
        token.burn(address(0), BURN_AMOUNT);
    }

    function test_Burn_ZeroAmount() public {
        token.mint(USER_BOB, MINT_AMOUNT);
        uint256 initialBalance = token.balanceOf(USER_BOB);
        uint256 initialSupply = token.totalSupply();

        token.burn(USER_BOB, 0);

        assertEq(token.balanceOf(USER_BOB), initialBalance, "Balance should not change");
        assertEq(token.totalSupply(), initialSupply, "Total supply should not change");
    }

    function test_Burn_EntireBalance() public {
        token.mint(USER_BOB, MINT_AMOUNT);
        token.burn(USER_BOB, MINT_AMOUNT);

        assertEq(token.balanceOf(USER_BOB), 0, "Balance should be zero");
    }

    ////////////////////////////////
    // TransferInternal Function Tests
    ////////////////////////////////

    function test_TransferInternal_Success() public {
        uint256 aliceInitialBalance = token.balanceOf(USER_ALICE);
        uint256 bobInitialBalance = token.balanceOf(USER_BOB);

        token.transferInternal(USER_ALICE, USER_BOB, TRANSFER_AMOUNT);

        assertEq(token.balanceOf(USER_ALICE), aliceInitialBalance - TRANSFER_AMOUNT, "Sender balance should decrease");
        assertEq(token.balanceOf(USER_BOB), bobInitialBalance + TRANSFER_AMOUNT, "Recipient balance should increase");
    }

    function test_TransferInternal_EmitsTransferEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(USER_ALICE, USER_BOB, TRANSFER_AMOUNT);

        token.transferInternal(USER_ALICE, USER_BOB, TRANSFER_AMOUNT);
    }

    function test_TransferInternal_InsufficientBalance() public {
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, USER_BOB, 0, TRANSFER_AMOUNT)
        );
        token.transferInternal(USER_BOB, USER_ALICE, TRANSFER_AMOUNT);
    }

    function test_TransferInternal_FromZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(0)));
        token.transferInternal(address(0), USER_BOB, TRANSFER_AMOUNT);
    }

    function test_TransferInternal_ToZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        token.transferInternal(USER_ALICE, address(0), TRANSFER_AMOUNT);
    }

    function test_TransferInternal_ZeroAmount() public {
        uint256 aliceInitialBalance = token.balanceOf(USER_ALICE);
        uint256 bobInitialBalance = token.balanceOf(USER_BOB);

        token.transferInternal(USER_ALICE, USER_BOB, 0);

        assertEq(token.balanceOf(USER_ALICE), aliceInitialBalance, "Sender balance should not change");
        assertEq(token.balanceOf(USER_BOB), bobInitialBalance, "Recipient balance should not change");
    }

    function test_TransferInternal_SelfTransfer() public {
        uint256 initialBalance = token.balanceOf(USER_ALICE);

        token.transferInternal(USER_ALICE, USER_ALICE, TRANSFER_AMOUNT);

        assertEq(token.balanceOf(USER_ALICE), initialBalance, "Self transfer should not change balance");
    }

    ////////////////////////////////
    // ApproveInternal Function Tests
    ////////////////////////////////

    function test_ApproveInternal_Success() public {
        token.approveInternal(USER_ALICE, USER_BOB, APPROVE_AMOUNT);

        assertEq(token.allowance(USER_ALICE, USER_BOB), APPROVE_AMOUNT, "Allowance should be set");
    }

    function test_ApproveInternal_EmitsApprovalEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Approval(USER_ALICE, USER_BOB, APPROVE_AMOUNT);

        token.approveInternal(USER_ALICE, USER_BOB, APPROVE_AMOUNT);
    }

    function test_ApproveInternal_OwnerZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidApprover.selector, address(0)));
        token.approveInternal(address(0), USER_BOB, APPROVE_AMOUNT);
    }

    function test_ApproveInternal_SpenderZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        token.approveInternal(USER_ALICE, address(0), APPROVE_AMOUNT);
    }

    function test_ApproveInternal_ZeroAmount() public {
        token.approveInternal(USER_ALICE, USER_BOB, 0);

        assertEq(token.allowance(USER_ALICE, USER_BOB), 0, "Zero allowance should be set");
    }

    function test_ApproveInternal_OverwriteAllowance() public {
        token.approveInternal(USER_ALICE, USER_BOB, APPROVE_AMOUNT);
        token.approveInternal(USER_ALICE, USER_BOB, APPROVE_AMOUNT * 2);

        assertEq(token.allowance(USER_ALICE, USER_BOB), APPROVE_AMOUNT * 2, "Allowance should be overwritten");
    }

    function test_ApproveInternal_MaxAllowance() public {
        uint256 maxAmount = type(uint256).max;
        token.approveInternal(USER_ALICE, USER_BOB, maxAmount);

        assertEq(token.allowance(USER_ALICE, USER_BOB), maxAmount, "Max allowance should be set");
    }

    ////////////////////////////////
    // Standard ERC20 Function Tests
    ////////////////////////////////

    function test_StandardTransfer_Success() public {
        vm.prank(USER_ALICE);
        bool success = token.transfer(USER_BOB, TRANSFER_AMOUNT);

        assertTrue(success, "Transfer should return true");
        assertEq(token.balanceOf(USER_ALICE), INITIAL_BALANCE - TRANSFER_AMOUNT, "Sender balance should decrease");
        assertEq(token.balanceOf(USER_BOB), TRANSFER_AMOUNT, "Recipient balance should increase");
    }

    function test_StandardApprove_Success() public {
        vm.prank(USER_ALICE);
        bool success = token.approve(USER_BOB, APPROVE_AMOUNT);

        assertTrue(success, "Approve should return true");
        assertEq(token.allowance(USER_ALICE, USER_BOB), APPROVE_AMOUNT, "Allowance should be set");
    }

    function test_StandardTransferFrom_Success() public {
        // Setup allowance
        vm.prank(USER_ALICE);
        token.approve(USER_BOB, APPROVE_AMOUNT);

        // Execute transferFrom
        vm.prank(USER_BOB);
        bool success = token.transferFrom(USER_ALICE, USER_CHARLIE, TRANSFER_AMOUNT);

        assertTrue(success, "TransferFrom should return true");
        assertEq(token.balanceOf(USER_ALICE), INITIAL_BALANCE - TRANSFER_AMOUNT, "Sender balance should decrease");
        assertEq(token.balanceOf(USER_CHARLIE), TRANSFER_AMOUNT, "Recipient balance should increase");
        assertEq(token.allowance(USER_ALICE, USER_BOB), APPROVE_AMOUNT - TRANSFER_AMOUNT, "Allowance should decrease");
    }

    ////////////////////////////////
    // Integration Tests
    ////////////////////////////////

    function test_MintBurnCycle() public {
        uint256 initialSupply = token.totalSupply();

        // Mint tokens
        token.mint(USER_BOB, MINT_AMOUNT);
        assertEq(token.totalSupply(), initialSupply + MINT_AMOUNT, "Supply should increase after mint");

        // Burn tokens
        token.burn(USER_BOB, MINT_AMOUNT);
        assertEq(token.totalSupply(), initialSupply, "Supply should return to initial after burn");
        assertEq(token.balanceOf(USER_BOB), 0, "User balance should be zero");
    }

    function test_ComplexTransferScenario() public {
        // Mint tokens to multiple users
        token.mint(USER_BOB, MINT_AMOUNT);
        token.mint(USER_CHARLIE, MINT_AMOUNT);

        // Setup allowances
        token.approveInternal(USER_ALICE, USER_BOB, APPROVE_AMOUNT);
        token.approveInternal(USER_BOB, USER_CHARLIE, APPROVE_AMOUNT);

        // Execute complex transfers
        token.transferInternal(USER_ALICE, USER_BOB, TRANSFER_AMOUNT);
        token.transferInternal(USER_BOB, USER_CHARLIE, TRANSFER_AMOUNT);

        // Verify final balances
        assertEq(token.balanceOf(USER_ALICE), INITIAL_BALANCE - TRANSFER_AMOUNT, "Alice balance correct");
        assertEq(token.balanceOf(USER_BOB), MINT_AMOUNT, "Bob balance correct");
        assertEq(token.balanceOf(USER_CHARLIE), MINT_AMOUNT + TRANSFER_AMOUNT, "Charlie balance correct");
    }

    ////////////////////////////////
    // Edge Cases
    ////////////////////////////////

    function test_MaxSupplyHandling() public {
        // This tests the theoretical maximum, though it would likely run out of gas in practice
        uint256 largeAmount = type(uint128).max;
        token.mint(USER_BOB, largeAmount);

        assertEq(token.balanceOf(USER_BOB), largeAmount, "Should handle very large amounts");
        assertGt(token.totalSupply(), INITIAL_BALANCE, "Total supply should increase significantly");
    }

    function test_ZeroAmountOperations() public {
        uint256 initialBalance = token.balanceOf(USER_ALICE);

        // Zero amount operations should not change state
        token.mint(USER_ALICE, 0);
        token.burn(USER_ALICE, 0);
        token.transferInternal(USER_ALICE, USER_BOB, 0);
        token.approveInternal(USER_ALICE, USER_BOB, 0);

        assertEq(token.balanceOf(USER_ALICE), initialBalance, "Balance should remain unchanged");
        assertEq(token.allowance(USER_ALICE, USER_BOB), 0, "Allowance should be zero");
    }

    ////////////////////////////////
    // Events
    ////////////////////////////////

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
