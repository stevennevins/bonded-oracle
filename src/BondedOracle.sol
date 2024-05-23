// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.20;

import {IBondedOracle} from "./IBondedOracle.sol";

contract BondedOracle is IBondedOracle {
    uint256 public nextQuestionId;
    mapping(uint256 => Question) public questions;
    mapping(uint256 => Answer) public answers;
    mapping(uint256 => mapping(address => uint256)) public claimedBonds;

    function postQuestion(
        uint32 openingTime,
        uint32 expiry,
        uint256 minBond,
        string memory question
    ) external payable returns (uint256) {
        if (expiry == 0 || expiry > 365 days) {
            revert InvalidExpiry();
        }

        bytes32 contentHash = keccak256(bytes(question));
        uint256 questionId = nextQuestionId;

        questions[questionId] = Question({
            openingTime: openingTime,
            asker: msg.sender,
            contentHash: contentHash,
            expiry: expiry,
            bounty: msg.value,
            minBond: minBond
        });

        nextQuestionId++;

        return questionId;
    }

    function cancelQuestion(uint256 questionId) external {
        Answer storage answer = answers[questionId];
        Question storage question = questions[questionId];
        if (questionId >= nextQuestionId) {
            revert QuestionDoesNotExist();
        }
        if (answer.historyHash != bytes32(0) || answer.finalizedTime != 0) {
            revert NotCancellable();
        }
        if (question.asker != msg.sender) {
            revert NotAuthorized();
        }
        answer.finalizedTime = block.timestamp;
        delete question.bounty;
        payable(question.asker).transfer(question.bounty);
    }

    function provideAnswer(uint256 questionId, bytes32 response) external payable {
        Question storage question = questions[questionId];
        Answer storage answer = answers[questionId];

        if (question.contentHash == 0) {
            revert QuestionDoesNotExist();
        }

        if (block.timestamp < question.openingTime) {
            revert OpeningTimeNotReached();
        }

        if (block.timestamp > question.openingTime + question.expiry) {
            revert AnswerPeriodClosed();
        }

        if (block.timestamp + 1 minutes > question.openingTime + question.expiry) {
            question.expiry += 5 minutes; // extend if answering right before end
        }

        if (msg.value < question.minBond) {
            revert BondTooLow();
        }

        question.minBond = msg.value * 2; // TODO: sqrt(value)*2)^2

        answer.response = response;
        answer.responder = msg.sender;
        answer.historyHash = keccak256(
            abi.encodePacked(answer.historyHash, response, msg.sender, msg.value, block.timestamp)
        );
    }

    function finalizeAnswer(uint256 questionId) external {
        Question storage question = questions[questionId];
        Answer storage answer = answers[questionId];

        if (question.contentHash == 0) {
            revert QuestionDoesNotExist();
        }

        if (answer.finalizedTime != 0) {
            revert AnswerAlreadyFinalized();
        }

        if (block.timestamp < question.openingTime + question.expiry) {
            revert FinalizationDeadlineNotReached();
        }

        answer.finalizedTime = block.timestamp;

        if (answer.historyHash == bytes32(0)) {
            payable(question.asker).transfer(question.bounty);
        } else {
            payable(answer.responder).transfer(question.bounty);
        }
    }

    /// TODO: need to also add a fee for bonding an answer
    function reclaimBond(uint256 questionId) external {
        Question storage question = questions[questionId];
        Answer storage answer = answers[questionId];

        if (question.contentHash == 0) {
            revert QuestionDoesNotExist();
        }

        if (answer.finalizedTime != 0) {
            revert AnswerNotFinalized();
        }
        /// TODO: assess answer for msg.sender, bonded value, and send back bond
    }

    function withdrawBounty(uint256 questionId) external {
        Question storage question = questions[questionId];
        Answer storage answer = answers[questionId];

        if (question.contentHash == 0) {
            revert QuestionDoesNotExist();
        }
        if (answer.finalizedTime == 0) {
            revert FinalizationDeadlineNotReached();
        }
        if (msg.sender != answer.responder) {
            revert InvalidAnswerer();
        }

        uint256 amount = question.bounty;
        if (question.bounty == 0) {
            revert BountyAlreadyClaimed();
        }
        delete question.bounty;
        payable(msg.sender).transfer(amount);
    }
}
