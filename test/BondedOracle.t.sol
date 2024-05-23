// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {BondedOracle} from "../src/BondedOracle.sol";
import {IBondedOracleEventsAndErrors} from "../src/IBondedOracleEventsAndErrors.sol";

contract BondedOracleTest is IBondedOracleEventsAndErrors, Test {
    BondedOracle oracle;

    receive() external payable {}

    function setUp() public {
        oracle = new BondedOracle();
    }

    function testPostQuestion() public {
        uint32 openingTime = uint32(block.timestamp + 1 days);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.postQuestion{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            question
        );

        (
            uint256 storedOpeningTime,
            address asker,
            bytes32 contentHash,
            uint256 storedExpiry,
            uint256 bounty,
            uint256 storedMinBond
        ) = oracle.questions(questionId);

        assertEq(storedOpeningTime, openingTime);
        assertEq(asker, address(this));
        assertEq(contentHash, keccak256(bytes(question)));
        assertEq(storedExpiry, expiry);
        assertEq(bounty, 1 ether);
        assertEq(storedMinBond, minBond);
    }

    function testPostQuestionInvalidExpiryZero() public {
        uint32 openingTime = uint32(block.timestamp + 1 days);
        uint32 expiry = 0;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        vm.expectRevert(InvalidExpiry.selector);
        oracle.postQuestion{value: 1 ether}(openingTime, expiry, minBond, question);
    }

    function testPostQuestionInvalidExpiryTooLong() public {
        uint32 openingTime = uint32(block.timestamp + 1 days);
        uint32 expiry = 366 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        vm.expectRevert(InvalidExpiry.selector);
        oracle.postQuestion{value: 1 ether}(openingTime, expiry, minBond, question);
    }

    function testCancelQuestion() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.postQuestion{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            question
        );

        oracle.cancelQuestion(questionId);

        (, , , , uint256 bounty, ) = oracle.questions(questionId);
        assertEq(bounty, 0);
    }

    function testCancelQuestionWithAnswer() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.postQuestion{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            question
        );

        bytes32 response = keccak256("Paris");
        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer{value: 2 ether}(questionId, response);

        vm.expectRevert(NotCancellable.selector);
        oracle.cancelQuestion(questionId);
    }

    function testCancelQuestionAlreadyFinalized() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.postQuestion{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            question
        );

        bytes32 response = keccak256("Paris");
        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer{value: 2 ether}(questionId, response);

        vm.warp(block.timestamp + 31 days);
        oracle.finalizeAnswer(questionId);

        vm.expectRevert(NotCancellable.selector);
        oracle.cancelQuestion(questionId);
    }

    function testCancelQuestionNonExistent() public {
        uint256 nonExistentQuestionId = 9999;

        vm.expectRevert(abi.encodeWithSignature("QuestionDoesNotExist()"));
        oracle.cancelQuestion(nonExistentQuestionId);
    }

    function testProvideAnswer() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.postQuestion{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            question
        );

        bytes32 response = keccak256("Paris");
        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer{value: 2 ether}(questionId, response);

        (bytes32 storedResponse, address responder, , ) = oracle.answers(questionId);
        assertEq(storedResponse, response);
        assertEq(responder, address(0x123));
    }

    function testProvideAnswerQuestionDoesNotExist() public {
        uint256 nonExistentQuestionId = 9999;
        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSignature("QuestionDoesNotExist()"));
        oracle.provideAnswer{value: 2 ether}(nonExistentQuestionId, response);
    }

    function testProvideAnswerOpeningTimeNotReached() public {
        uint32 openingTime = uint32(block.timestamp + 1 days);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.postQuestion{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            question
        );

        bytes32 response = keccak256("Paris");
        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSignature("OpeningTimeNotReached()"));
        oracle.provideAnswer{value: 2 ether}(questionId, response);
    }

    function testProvideAnswerAnswerPeriodClosed() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.postQuestion{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            question
        );

        bytes32 response = keccak256("Paris");
        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        vm.warp(block.timestamp + 31 days);
        vm.expectRevert(abi.encodeWithSignature("AnswerPeriodClosed()"));
        oracle.provideAnswer{value: 2 ether}(questionId, response);
    }

    function testProvideAnswerBondTooLow() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.postQuestion{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            question
        );

        bytes32 response = keccak256("Paris");
        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSignature("BondTooLow()"));
        oracle.provideAnswer{value: 0.5 ether}(questionId, response);
    }

    function testProvideMultipleAnswers() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.postQuestion{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            question
        );

        bytes32 response1 = keccak256("Paris");
        bytes32 response2 = keccak256("Lyon");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer{value: 1 ether}(questionId, response1);

        vm.deal(address(0x456), 100 ether);
        vm.prank(address(0x456));
        oracle.provideAnswer{value: 2 ether}(questionId, response2);

        (bytes32 finalResponse, address responder, , ) = oracle.answers(questionId);
        assertEq(finalResponse, response2);
        assertEq(responder, address(0x456));
    }

    function testFinalizeAnswerSuccess() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.postQuestion{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer{value: 1 ether}(questionId, response);

        vm.warp(block.timestamp + expiry + 1);

        oracle.finalizeAnswer(questionId);

        (bytes32 finalResponse, address responder, uint256 finalizedTime, ) = oracle.answers(
            questionId
        );
        assertEq(finalResponse, response);
        assertEq(responder, address(0x123));
        assert(finalizedTime > 0);
    }

    function testFinalizeAnswerQuestionDoesNotExist() public {
        uint256 invalidQuestionId = 999;

        vm.expectRevert(abi.encodeWithSignature("QuestionDoesNotExist()"));
        oracle.finalizeAnswer(invalidQuestionId);
    }

    function testFinalizeAnswerAlreadyFinalized() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.postQuestion{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer{value: 1 ether}(questionId, response);

        vm.warp(block.timestamp + expiry + 1);

        oracle.finalizeAnswer(questionId);

        vm.expectRevert(abi.encodeWithSignature("AnswerAlreadyFinalized()"));
        oracle.finalizeAnswer(questionId);
    }

    function testFinalizeAnswerFinalizationDeadlineNotReached() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.postQuestion{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer{value: 1 ether}(questionId, response);

        vm.expectRevert(abi.encodeWithSignature("FinalizationDeadlineNotReached()"));
        oracle.finalizeAnswer(questionId);
    }

    function testWithdrawBountySuccess() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.postQuestion{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer{value: 1 ether}(questionId, response);

        vm.warp(block.timestamp + expiry + 1);

        oracle.finalizeAnswer(questionId);

        vm.prank(address(0x123));
        oracle.withdrawBounty(questionId);
    }

    function testWithdrawBountyQuestionDoesNotExist() public {
        vm.expectRevert(abi.encodeWithSignature("QuestionDoesNotExist()"));
        oracle.withdrawBounty(999);
    }

    function testWithdrawBountyFinalizationDeadlineNotReached() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.postQuestion{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer{value: 1 ether}(questionId, response);

        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSignature("FinalizationDeadlineNotReached()"));
        oracle.withdrawBounty(questionId);
    }

    function testWithdrawBountyInvalidAnswerer() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.postQuestion{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer{value: 1 ether}(questionId, response);

        vm.warp(block.timestamp + expiry + 1);

        oracle.finalizeAnswer(questionId);

        vm.prank(address(0x456));
        vm.expectRevert(abi.encodeWithSignature("InvalidAnswerer()"));
        oracle.withdrawBounty(questionId);
    }

    function testCancelQuestionCannotBeCalledTwice() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.postQuestion{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            question
        );

        oracle.cancelQuestion(questionId);

        vm.expectRevert(NotCancellable.selector);
        oracle.cancelQuestion(questionId);
    }

    function testWithdrawBountyCannotBeCalledTwice() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.postQuestion{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer{value: 1 ether}(questionId, response);

        vm.warp(block.timestamp + expiry + 1);

        oracle.finalizeAnswer(questionId);

        vm.prank(address(0x123));
        oracle.withdrawBounty(questionId);

        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSignature("BountyAlreadyClaimed()"));
        oracle.withdrawBounty(questionId);
    }

    function testFinalizeAnswerCannotBeCalledTwice() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.postQuestion{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer{value: 1 ether}(questionId, response);

        vm.warp(block.timestamp + expiry + 1);

        oracle.finalizeAnswer(questionId);

        vm.expectRevert(abi.encodeWithSignature("AnswerAlreadyFinalized()"));
        oracle.finalizeAnswer(questionId);
    }
}
