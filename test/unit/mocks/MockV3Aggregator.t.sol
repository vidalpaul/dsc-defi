// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {MockV3Aggregator} from "../../mocks/MockV3Aggregator.sol";

/**
 * @title MockV3Aggregator_Unit_Test
 * @author @vidalpaul
 * @notice Comprehensive unit test suite for MockV3Aggregator contract
 * @dev Tests all Chainlink V3 Aggregator mock functionality including price updates and historical data
 */
contract MockV3Aggregator_Unit_Test is Test {
    MockV3Aggregator public aggregator;

    // Test constants
    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_ANSWER = 2000e8; // $2000 with 8 decimals
    int256 public constant UPDATED_ANSWER = 2500e8; // $2500 with 8 decimals
    int256 public constant NEGATIVE_ANSWER = -1000e8; // Negative price for edge case testing

    function setUp() public {
        aggregator = new MockV3Aggregator(DECIMALS, INITIAL_ANSWER);
    }

    ////////////////////////////////
    // Constructor Tests
    ////////////////////////////////

    function test_Constructor_SetsDecimals() public view {
        assertEq(aggregator.decimals(), DECIMALS, "Decimals should be set correctly");
    }

    function test_Constructor_SetsInitialAnswer() public view {
        assertEq(aggregator.latestAnswer(), INITIAL_ANSWER, "Initial answer should be set");
    }

    function test_Constructor_SetsInitialRound() public view {
        assertEq(aggregator.latestRound(), 1, "Initial round should be 1");
    }

    function test_Constructor_SetsInitialTimestamp() public view {
        assertGt(aggregator.latestTimestamp(), 0, "Initial timestamp should be set");
        assertEq(aggregator.latestTimestamp(), block.timestamp, "Initial timestamp should be current block timestamp");
    }

    function test_Constructor_SetsVersion() public view {
        assertEq(aggregator.version(), 0, "Version should be 0");
    }

    function test_Constructor_SetsDescription() public view {
        assertEq(aggregator.description(), "v0.8/tests/MockV3Aggregator.sol", "Description should be set correctly");
    }

    function test_Constructor_ZeroDecimals() public {
        MockV3Aggregator zeroDecimalAggregator = new MockV3Aggregator(0, INITIAL_ANSWER);
        assertEq(zeroDecimalAggregator.decimals(), 0, "Zero decimals should work");
    }

    function test_Constructor_MaxDecimals() public {
        uint8 maxDecimals = type(uint8).max;
        MockV3Aggregator maxDecimalAggregator = new MockV3Aggregator(maxDecimals, INITIAL_ANSWER);
        assertEq(maxDecimalAggregator.decimals(), maxDecimals, "Max decimals should work");
    }

    function test_Constructor_NegativeInitialAnswer() public {
        MockV3Aggregator negativeAggregator = new MockV3Aggregator(DECIMALS, NEGATIVE_ANSWER);
        assertEq(negativeAggregator.latestAnswer(), NEGATIVE_ANSWER, "Negative initial answer should work");
    }

    function test_Constructor_ZeroInitialAnswer() public {
        MockV3Aggregator zeroAggregator = new MockV3Aggregator(DECIMALS, 0);
        assertEq(zeroAggregator.latestAnswer(), 0, "Zero initial answer should work");
    }

    ////////////////////////////////
    // UpdateAnswer Function Tests
    ////////////////////////////////

    function test_UpdateAnswer_Success() public {
        uint256 initialTimestamp = aggregator.latestTimestamp();
        uint256 initialRound = aggregator.latestRound();

        // Move forward in time to ensure timestamp changes
        vm.warp(block.timestamp + 1);

        aggregator.updateAnswer(UPDATED_ANSWER);

        assertEq(aggregator.latestAnswer(), UPDATED_ANSWER, "Answer should be updated");
        assertGt(aggregator.latestTimestamp(), initialTimestamp, "Timestamp should be updated");
        assertEq(aggregator.latestRound(), initialRound + 1, "Round should increment");
    }

    function test_UpdateAnswer_UpdatesHistoricalData() public {
        uint256 currentRound = aggregator.latestRound();

        aggregator.updateAnswer(UPDATED_ANSWER);

        uint256 newRound = aggregator.latestRound();
        assertEq(aggregator.getAnswer(newRound), UPDATED_ANSWER, "Historical answer should be stored");
        assertEq(aggregator.getTimestamp(newRound), block.timestamp, "Historical timestamp should be stored");
    }

    function test_UpdateAnswer_MultipleUpdates() public {
        int256 firstUpdate = 3000e8;
        int256 secondUpdate = 3500e8;

        aggregator.updateAnswer(firstUpdate);
        uint256 firstRound = aggregator.latestRound();

        vm.warp(block.timestamp + 1);
        aggregator.updateAnswer(secondUpdate);
        uint256 secondRound = aggregator.latestRound();

        assertEq(aggregator.getAnswer(firstRound), firstUpdate, "First update should be stored");
        assertEq(aggregator.getAnswer(secondRound), secondUpdate, "Second update should be stored");
        assertEq(aggregator.latestAnswer(), secondUpdate, "Latest answer should be second update");
        assertEq(secondRound, firstRound + 1, "Rounds should increment correctly");
    }

    function test_UpdateAnswer_NegativeValue() public {
        aggregator.updateAnswer(NEGATIVE_ANSWER);

        assertEq(aggregator.latestAnswer(), NEGATIVE_ANSWER, "Negative answer should be accepted");
    }

    function test_UpdateAnswer_ZeroValue() public {
        aggregator.updateAnswer(0);

        assertEq(aggregator.latestAnswer(), 0, "Zero answer should be accepted");
    }

    function test_UpdateAnswer_MaxValue() public {
        int256 maxValue = type(int256).max;
        aggregator.updateAnswer(maxValue);

        assertEq(aggregator.latestAnswer(), maxValue, "Max value should be accepted");
    }

    function test_UpdateAnswer_MinValue() public {
        int256 minValue = type(int256).min;
        aggregator.updateAnswer(minValue);

        assertEq(aggregator.latestAnswer(), minValue, "Min value should be accepted");
    }

    ////////////////////////////////
    // UpdateRoundData Function Tests
    ////////////////////////////////

    function test_UpdateRoundData_Success() public {
        uint80 newRoundId = 100;
        int256 newAnswer = 4000e8;
        uint256 newTimestamp = block.timestamp + 3600;
        uint256 newStartedAt = block.timestamp + 3500;

        aggregator.updateRoundData(newRoundId, newAnswer, newTimestamp, newStartedAt);

        assertEq(aggregator.latestRound(), newRoundId, "Round should be updated");
        assertEq(aggregator.latestAnswer(), newAnswer, "Answer should be updated");
        assertEq(aggregator.latestTimestamp(), newTimestamp, "Timestamp should be updated");
        assertEq(aggregator.getAnswer(newRoundId), newAnswer, "Historical answer should be stored");
        assertEq(aggregator.getTimestamp(newRoundId), newTimestamp, "Historical timestamp should be stored");
    }

    function test_UpdateRoundData_BackwardsRoundId() public {
        // First update with a high round ID
        aggregator.updateRoundData(100, UPDATED_ANSWER, block.timestamp, block.timestamp);

        // Then update with a lower round ID (should still work as this is a mock)
        aggregator.updateRoundData(50, INITIAL_ANSWER, block.timestamp + 1, block.timestamp + 1);

        assertEq(aggregator.latestRound(), 50, "Should allow backwards round ID in mock");
        assertEq(aggregator.latestAnswer(), INITIAL_ANSWER, "Should update answer even with backwards round");
    }

    function test_UpdateRoundData_ZeroRoundId() public {
        aggregator.updateRoundData(0, UPDATED_ANSWER, block.timestamp, block.timestamp);

        assertEq(aggregator.latestRound(), 0, "Zero round ID should be accepted");
        assertEq(aggregator.latestAnswer(), UPDATED_ANSWER, "Answer should be updated");
    }

    function test_UpdateRoundData_FutureTimestamp() public {
        uint256 futureTimestamp = block.timestamp + 1 days;
        aggregator.updateRoundData(10, UPDATED_ANSWER, futureTimestamp, futureTimestamp - 100);

        assertEq(aggregator.latestTimestamp(), futureTimestamp, "Future timestamp should be accepted");
    }

    function test_UpdateRoundData_MaxRoundId() public {
        uint80 maxRoundId = type(uint80).max;
        aggregator.updateRoundData(maxRoundId, UPDATED_ANSWER, block.timestamp, block.timestamp);

        assertEq(aggregator.latestRound(), maxRoundId, "Max round ID should be accepted");
    }

    ////////////////////////////////
    // GetRoundData Function Tests
    ////////////////////////////////

    function test_GetRoundData_ExistingRound() public {
        uint80 testRoundId = 5;
        int256 testAnswer = 3000e8;
        uint256 testTimestamp = block.timestamp + 100;
        uint256 testStartedAt = block.timestamp + 50;

        aggregator.updateRoundData(testRoundId, testAnswer, testTimestamp, testStartedAt);

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            aggregator.getRoundData(testRoundId);

        assertEq(roundId, testRoundId, "Round ID should match");
        assertEq(answer, testAnswer, "Answer should match");
        assertEq(startedAt, testStartedAt, "Started at should match");
        assertEq(updatedAt, testTimestamp, "Updated at should match");
        assertEq(answeredInRound, testRoundId, "Answered in round should match round ID");
    }

    function test_GetRoundData_NonExistentRound() public view {
        uint80 nonExistentRoundId = 999;

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            aggregator.getRoundData(nonExistentRoundId);

        assertEq(roundId, nonExistentRoundId, "Round ID should match request");
        assertEq(answer, 0, "Answer should be zero for non-existent round");
        assertEq(startedAt, 0, "Started at should be zero for non-existent round");
        assertEq(updatedAt, 0, "Updated at should be zero for non-existent round");
        assertEq(answeredInRound, nonExistentRoundId, "Answered in round should match request");
    }

    function test_GetRoundData_ZeroRoundId() public view {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            aggregator.getRoundData(0);

        assertEq(roundId, 0, "Round ID should be zero");
        assertEq(answer, 0, "Answer should be zero for round 0");
        assertEq(startedAt, 0, "Started at should be zero for round 0");
        assertEq(updatedAt, 0, "Updated at should be zero for round 0");
        assertEq(answeredInRound, 0, "Answered in round should be zero");
    }

    ////////////////////////////////
    // LatestRoundData Function Tests
    ////////////////////////////////

    function test_LatestRoundData_InitialState() public view {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            aggregator.latestRoundData();

        assertEq(roundId, 1, "Initial round ID should be 1");
        assertEq(answer, INITIAL_ANSWER, "Initial answer should match constructor");
        assertEq(startedAt, block.timestamp, "Started at should be current timestamp");
        assertEq(updatedAt, block.timestamp, "Updated at should be current timestamp");
        assertEq(answeredInRound, 1, "Answered in round should be 1");
    }

    function test_LatestRoundData_AfterUpdate() public {
        aggregator.updateAnswer(UPDATED_ANSWER);

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            aggregator.latestRoundData();

        assertEq(roundId, 2, "Round ID should be 2 after one update");
        assertEq(answer, UPDATED_ANSWER, "Answer should be updated value");
        assertEq(startedAt, block.timestamp, "Started at should be current timestamp");
        assertEq(updatedAt, block.timestamp, "Updated at should be current timestamp");
        assertEq(answeredInRound, 2, "Answered in round should be 2");
    }

    function test_LatestRoundData_AfterRoundDataUpdate() public {
        uint80 customRoundId = 42;
        int256 customAnswer = 5000e8;
        uint256 customTimestamp = block.timestamp + 200;
        uint256 customStartedAt = block.timestamp + 150;

        aggregator.updateRoundData(customRoundId, customAnswer, customTimestamp, customStartedAt);

        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            aggregator.latestRoundData();

        assertEq(roundId, customRoundId, "Round ID should match custom value");
        assertEq(answer, customAnswer, "Answer should match custom value");
        assertEq(startedAt, customStartedAt, "Started at should match custom value");
        assertEq(updatedAt, customTimestamp, "Updated at should match custom value");
        assertEq(answeredInRound, customRoundId, "Answered in round should match custom round ID");
    }

    ////////////////////////////////
    // Edge Cases and Integration Tests
    ////////////////////////////////

    function test_MultipleUpdatesSequence() public {
        int256[] memory answers = new int256[](5);
        answers[0] = 1000e8;
        answers[1] = 1500e8;
        answers[2] = 2000e8;
        answers[3] = 1800e8;
        answers[4] = 2200e8;

        for (uint256 i = 0; i < answers.length; i++) {
            vm.warp(block.timestamp + 1);
            aggregator.updateAnswer(answers[i]);
        }

        assertEq(aggregator.latestAnswer(), answers[4], "Final answer should be last update");
        assertEq(aggregator.latestRound(), 1 + answers.length, "Round should increment for each update");

        // Verify historical data
        for (uint256 i = 0; i < answers.length; i++) {
            assertEq(aggregator.getAnswer(i + 2), answers[i], "Historical answer should be preserved");
        }
    }

    function test_TimestampProgression() public {
        uint256 startTime = block.timestamp;

        for (uint256 i = 1; i <= 3; i++) {
            uint256 targetTime = startTime + i * 100;
            vm.warp(targetTime);
            aggregator.updateAnswer(int256(1000e8 + i * 100e8));

            assertEq(aggregator.latestTimestamp(), targetTime, "Timestamp should progress correctly");
        }
    }

    function test_RoundIdConsistency() public {
        uint80 customRoundId = 500;
        aggregator.updateRoundData(customRoundId, UPDATED_ANSWER, block.timestamp, block.timestamp);

        // Use updateAnswer after updateRoundData
        aggregator.updateAnswer(INITIAL_ANSWER);

        assertEq(aggregator.latestRound(), customRoundId + 1, "Round should increment from custom round ID");
    }

    function test_ExtremeValues() public {
        // Test extreme positive value
        int256 maxValue = type(int256).max;
        aggregator.updateAnswer(maxValue);
        assertEq(aggregator.latestAnswer(), maxValue, "Should handle max int256 value");

        // Test extreme negative value
        int256 minValue = type(int256).min;
        aggregator.updateAnswer(minValue);
        assertEq(aggregator.latestAnswer(), minValue, "Should handle min int256 value");

        // Test zero
        aggregator.updateAnswer(0);
        assertEq(aggregator.latestAnswer(), 0, "Should handle zero value");
    }

    function test_RapidUpdates() public {
        uint256 updateCount = 10;
        uint256 baseTime = block.timestamp;

        for (uint256 i = 0; i < updateCount; i++) {
            vm.warp(baseTime + i);
            aggregator.updateAnswer(int256(1000e8 + i * 10e8));
        }

        assertEq(aggregator.latestRound(), 1 + updateCount, "All rapid updates should be processed");
        assertEq(aggregator.latestAnswer(), int256(1000e8 + (updateCount - 1) * 10e8), "Final answer should be correct");
    }

    ////////////////////////////////
    // View Function Tests
    ////////////////////////////////

    function test_ViewFunctions_Consistency() public view {
        // Test that view functions return consistent data
        (uint80 roundId, int256 answer,, uint256 updatedAt,) = aggregator.latestRoundData();

        assertEq(roundId, aggregator.latestRound(), "Round ID should be consistent");
        assertEq(answer, aggregator.latestAnswer(), "Answer should be consistent");
        assertEq(updatedAt, aggregator.latestTimestamp(), "Timestamp should be consistent");
    }

    function test_ConstantViewFunctions() public view {
        // These should never change
        assertEq(aggregator.version(), 0, "Version should always be 0");
        assertEq(aggregator.description(), "v0.8/tests/MockV3Aggregator.sol", "Description should be constant");
        assertEq(aggregator.decimals(), DECIMALS, "Decimals should be constant");
    }
}
