// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {BondedOracle} from "../src/BondedOracle.sol";
import {Encumberable} from "../src/EncumberedToken.sol";
import {IBondedOracleEventsAndErrors} from "../src/IBondedOracleEventsAndErrors.sol";

contract BondedOracleTest is IBondedOracleEventsAndErrors, Test {
    BondedOracle internal oracle;
    address internal slashableAsset;

    receive() external payable {}

    function setUp() public {
        oracle = new BondedOracle();
        slashableAsset = address(new Encumberable());
        Encumberable(slashableAsset).mint(address(this), 100 ether);
        Encumberable(slashableAsset).approve(address(oracle), type(uint256).max);
        Encumberable(slashableAsset).mint(address(0x123), 100 ether);
        vm.prank(address(0x123));
        Encumberable(slashableAsset).approve(address(oracle), type(uint256).max);
        Encumberable(slashableAsset).mint(address(0x456), 100 ether);
        vm.prank(address(0x456));
        Encumberable(slashableAsset).approve(address(oracle), type(uint256).max);
    }

    function testRequestAnswer() public {
        uint32 openingTime = uint32(block.timestamp + 1 days);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        (
            uint256 storedOpeningTime,
            address asker,
            bytes32 contentHash,
            uint256 storedExpiry,
            uint256 bounty,
            uint256 storedMinBond,
            address slashableAsset
        ) = oracle.questions(questionId);

        assertEq(storedOpeningTime, openingTime);
        assertEq(asker, address(this));
        assertEq(contentHash, keccak256(bytes(question)));
        assertEq(storedExpiry, expiry);
        assertEq(bounty, 1 ether);
        assertEq(storedMinBond, minBond);
    }

    function testRequestAnswerInvalidExpiryZero() public {
        uint32 openingTime = uint32(block.timestamp + 1 days);
        uint32 expiry = 0;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        vm.expectRevert(InvalidExpiry.selector);
        oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );
    }

    function testRequestAnswerInvalidExpiryTooLong() public {
        uint32 openingTime = uint32(block.timestamp + 1 days);
        uint32 expiry = 366 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        vm.expectRevert(InvalidExpiry.selector);
        oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );
    }

    function testCancelRequest() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        oracle.cancelRequest(questionId);

        (, , , , uint256 bounty, , ) = oracle.questions(questionId);
        assertEq(bounty, 0);
    }

    function testCancelRequestWithAnswer() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response = keccak256("Paris");
        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer(questionId, response, 2e18);

        vm.expectRevert(NotCancellable.selector);
        oracle.cancelRequest(questionId);
    }

    function testCancelRequestAlreadyFinalized() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response = keccak256("Paris");
        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer(questionId, response, 2e18);

        vm.warp(block.timestamp + 31 days);
        oracle.finalizeAnswer(questionId);

        vm.expectRevert(NotCancellable.selector);
        oracle.cancelRequest(questionId);
    }

    function testCancelRequestNonExistent() public {
        uint256 nonExistentQuestionId = 9999;

        vm.expectRevert(abi.encodeWithSignature("QuestionDoesNotExist()"));
        oracle.cancelRequest(nonExistentQuestionId);
    }

    function testProvideAnswer() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response = keccak256("Paris");
        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer(questionId, response, 2e18);

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
        oracle.provideAnswer(nonExistentQuestionId, response, 2e18);
    }

    function testProvideAnswerOpeningTimeNotReached() public {
        uint32 openingTime = uint32(block.timestamp + 1 days);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response = keccak256("Paris");
        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSignature("OpeningTimeNotReached()"));
        oracle.provideAnswer(questionId, response, 2e18);
    }

    function testProvideAnswerAnswerPeriodClosed() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response = keccak256("Paris");
        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        vm.warp(block.timestamp + 31 days);
        vm.expectRevert(abi.encodeWithSignature("AnswerPeriodClosed()"));
        oracle.provideAnswer(questionId, response, 1e18);
    }

    function testProvideAnswerBondTooLow() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response = keccak256("Paris");
        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSignature("BondTooLow()"));
        oracle.provideAnswer(questionId, response, 0.5e18);
    }

    function testProvideMultipleAnswers() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response1 = keccak256("Paris");
        bytes32 response2 = keccak256("Lyon");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer(questionId, response1, 1e18);

        vm.deal(address(0x456), 100 ether);
        vm.prank(address(0x456));
        oracle.provideAnswer(questionId, response2, 2e18);

        (bytes32 finalResponse, address responder, , ) = oracle.answers(questionId);
        assertEq(finalResponse, response2);
        assertEq(responder, address(0x456));
    }

    function testFinalizeAnswerSuccess() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer(questionId, response, 1e18);

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

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer(questionId, response, 1e18);

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

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer(questionId, response, 1e18);

        vm.expectRevert(abi.encodeWithSignature("FinalizationDeadlineNotReached()"));
        oracle.finalizeAnswer(questionId);
    }

    function testWithdrawBountySuccess() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer(questionId, response, 1e18);

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

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer(questionId, response, 1e18);

        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSignature("FinalizationDeadlineNotReached()"));
        oracle.withdrawBounty(questionId);
    }

    function testWithdrawBountyInvalidAnswerer() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer(questionId, response, 1e18);

        vm.warp(block.timestamp + expiry + 1);

        oracle.finalizeAnswer(questionId);

        vm.prank(address(0x456));
        vm.expectRevert(abi.encodeWithSignature("InvalidAnswerer()"));
        oracle.withdrawBounty(questionId);
    }

    function testCancelRequestCannotBeCalledTwice() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        oracle.cancelRequest(questionId);

        vm.expectRevert(NotCancellable.selector);
        oracle.cancelRequest(questionId);
    }

    function testWithdrawBountyCannotBeCalledTwice() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer(questionId, response, 1e18);

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

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer(questionId, response, 1e18);

        vm.warp(block.timestamp + expiry + 1);

        oracle.finalizeAnswer(questionId);

        vm.expectRevert(abi.encodeWithSignature("AnswerAlreadyFinalized()"));
        oracle.finalizeAnswer(questionId);
    }

    function testRecomputeHistoryHash() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response1 = keccak256("Paris");
        bytes32 response2 = keccak256("Lyon");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer(questionId, response1, 1e18);

        vm.deal(address(0x456), 100 ether);
        vm.prank(address(0x456));
        oracle.provideAnswer(questionId, response2, 2e18);

        bytes32[] memory previousHashes = new bytes32[](2);
        previousHashes[0] = keccak256(
            abi.encodePacked(response1, address(0x123), uint256(1 ether))
        );
        previousHashes[1] = keccak256(
            abi.encodePacked(response2, address(0x456), uint256(2 ether))
        );

        bytes32 expectedHash = keccak256(
            abi.encodePacked(
                keccak256(abi.encodePacked(bytes32(0), previousHashes[0])),
                previousHashes[1]
            )
        );

        bytes32 recomputedHash = oracle.recomputeHistoryHash(previousHashes);

        assertEq(recomputedHash, expectedHash);
    }

    function testReclaimBondSuccess() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer(questionId, response, 1e18);

        vm.warp(block.timestamp + expiry + 1);
        oracle.finalizeAnswer(questionId);

        bytes32[] memory previousHashes = new bytes32[](1);
        previousHashes[0] = keccak256(abi.encodePacked(response, address(0x123), uint256(1 ether)));

        vm.prank(address(0x123));
        oracle.reclaimBond(questionId, response, previousHashes);
    }

    function testReclaimBondQuestionDoesNotExist() public {
        bytes32 response = keccak256("Paris");
        bytes32[] memory previousHashes = new bytes32[](1);
        previousHashes[0] = keccak256(abi.encodePacked(response, address(0x123), uint256(1 ether)));

        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSignature("QuestionDoesNotExist()"));
        oracle.reclaimBond(999, response, previousHashes);
    }

    function testReclaimBondAnswerNotFinalized() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer(questionId, response, 1e18);

        bytes32[] memory previousHashes = new bytes32[](1);
        previousHashes[0] = keccak256(abi.encodePacked(response, address(0x123), uint256(1 ether)));

        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSignature("AnswerNotFinalized()"));
        oracle.reclaimBond(questionId, response, previousHashes);
    }

    function testReclaimBondNotFound() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer(questionId, response, 1e18);

        vm.warp(block.timestamp + expiry + 1);
        oracle.finalizeAnswer(questionId);

        bytes32[] memory previousHashes = new bytes32[](1);
        previousHashes[0] = keccak256(abi.encodePacked(response, address(0x456), uint256(1 ether)));

        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSignature("NotFound()"));
        oracle.reclaimBond(questionId, response, previousHashes);
    }

    function testReclaimBondInvalidHistoryHash() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        bytes32 response = keccak256("Paris");

        vm.deal(address(0x123), 100 ether);
        vm.prank(address(0x123));
        oracle.provideAnswer(questionId, response, 1e18);

        vm.deal(address(0x124), 100 ether);
        vm.prank(address(0x124));
        Encumberable(slashableAsset).mint(address(124), 100 ether);
        Encumberable(slashableAsset).approve(address(oracle), 100 ether);
        oracle.provideAnswer(questionId, response, 2e18);

        vm.warp(block.timestamp + expiry + 1);
        oracle.finalizeAnswer(questionId);

        bytes32[] memory previousHashes = new bytes32[](2);
        previousHashes[0] = keccak256(abi.encodePacked(response, address(0x123), uint256(1 ether)));

        // Modify the previousHashes to create an invalid history hash
        previousHashes[1] = keccak256(abi.encodePacked(response, address(0x123), uint256(1 ether)));

        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSignature("InvalidHistoryHash()"));
        oracle.reclaimBond(questionId, response, previousHashes);
    }

    function testSetObserver() public {
        uint32 openingTime = uint32(block.timestamp + 1 days);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        address observer = address(0x789);

        vm.prank(address(this));
        oracle.setObserver(questionId, observer);

        address storedObserver = oracle.observers(questionId);
        assertEq(storedObserver, observer);
    }

    function testSetObserverNotAuthorized() public {
        uint32 openingTime = uint32(block.timestamp + 1 days);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        address observer = address(0x789);

        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized()"));
        oracle.setObserver(questionId, observer);
    }

    function testSetObserverQuestionDoesNotExist() public {
        uint256 invalidQuestionId = 9999;
        address observer = address(0x789);

        vm.prank(address(this));
        vm.expectRevert(abi.encodeWithSignature("QuestionDoesNotExist()"));
        oracle.setObserver(invalidQuestionId, observer);
    }

    function testSetObserverOpeningTimeNotReached() public {
        uint32 openingTime = uint32(block.timestamp + 1 days);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        address observer = address(0x789);

        vm.prank(address(this));
        oracle.setObserver(questionId, observer);
    }

    function testProvideAnswerWithObserver() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        address observer = address(0x789);
        Encumberable(slashableAsset).mint(observer, 100 ether);
        vm.prank(observer);
        Encumberable(slashableAsset).approve(address(oracle), 100 ether);
        vm.prank(address(this));
        oracle.setObserver(questionId, observer);

        bytes32 response = keccak256("Paris");
        Encumberable(slashableAsset).mint(observer, 100 ether);
        vm.prank(observer);
        Encumberable(slashableAsset).approve(address(oracle), 100 ether);
        vm.prank(observer);
        oracle.provideAnswer(questionId, response, 1e18);

        (bytes32 finalResponse, address responder, , ) = oracle.answers(questionId);
        assertEq(finalResponse, response);
        assertEq(responder, observer);
    }

    function testProvideAnswerWithObserverNotAuthorized() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        address observer = address(0x789);
        vm.prank(address(this));
        oracle.setObserver(questionId, observer);

        bytes32 response = keccak256("Paris");
        Encumberable(slashableAsset).mint(address(0x123), 100 ether);
        vm.prank(address(0x123));
        vm.expectRevert(abi.encodeWithSignature("NotAuthorized()"));
        oracle.provideAnswer(questionId, response, 1e18);
    }

    function testProvideAnswerWithObserverBondTooLow() public {
        uint32 openingTime = uint32(block.timestamp);
        uint32 expiry = 30 days;
        uint256 minBond = 1 ether;
        string memory question = "What is the capital of France?";

        uint256 questionId = oracle.requestAnswer{value: 1 ether}(
            openingTime,
            expiry,
            minBond,
            slashableAsset,
            question
        );

        address observer = address(0x789);
        Encumberable(slashableAsset).mint(observer, 100 ether);
        vm.prank(observer);
        Encumberable(slashableAsset).approve(address(oracle), 100 ether);
        vm.prank(address(this));
        oracle.setObserver(questionId, observer);

        bytes32 response = keccak256("Paris");
        vm.prank(observer);
        vm.expectRevert(abi.encodeWithSignature("BondTooLow()"));
        oracle.provideAnswer(questionId, response, 0.5e18);
    }
}
