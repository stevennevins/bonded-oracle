// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.20;

import {IBondedOracle} from "./IBondedOracle.sol";
import {EncumberedToken} from "./EncumberedToken.sol";

/**
 * @title BondedOracle
 * @notice A decentralized oracle leveraging economic incentives for reliable and secure answers.
 * @dev Implements bounty and bond mechanisms to align participant incentives with accurate information provision.
 */
contract BondedOracle is IBondedOracle {
    /// @inheritdoc IBondedOracle
    uint256 public nextQuestionId;

    /// @inheritdoc IBondedOracle
    mapping(uint256 => Question) public questions;

    /// @inheritdoc IBondedOracle
    mapping(uint256 => address) public observers;

    /// @inheritdoc IBondedOracle
    mapping(uint256 => Answer) public answers;

    /// @inheritdoc IBondedOracle
    mapping(uint256 => mapping(address => uint256)) public bonds;

    /// @inheritdoc IBondedOracle
    function setObserver(uint256 questionId, address observer) external {
        Question storage question = questions[questionId];
        if (questionId >= nextQuestionId) {
            revert QuestionDoesNotExist();
        }
        if (question.openingTime < block.timestamp) {
            revert ObserverNotAssignable();
        }
        if (question.asker != msg.sender) {
            revert NotAuthorized();
        }
        observers[questionId] = observer;
    }

    /// @inheritdoc IBondedOracle
    function requestAnswer(
        uint32 openingTime,
        uint32 expiry,
        uint256 minBond,
        address slashableAsset,
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
            minBond: minBond,
            slashableAsset: slashableAsset
        });

        nextQuestionId++;

        return questionId;
    }

    /// @inheritdoc IBondedOracle
    function cancelRequest(uint256 questionId) external {
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
        uint256 bounty = question.bounty;
        delete question.bounty;
        payable(question.asker).transfer(bounty);
    }

    /// @inheritdoc IBondedOracle
    function provideAnswer(uint256 questionId, bytes32 response, uint256 bond) external {
        Question storage question = questions[questionId];
        Answer storage answer = answers[questionId];

        address observer = observers[questionId];
        if (observer != address(0) && msg.sender != observer) {
            revert NotAuthorized();
        }

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
        EncumberedToken(question.slashableAsset).encumberFrom(msg.sender, address(this), bond);

        uint256 currentBond = bonds[questionId][msg.sender];
        uint256 newBond = currentBond + bond;

        if (newBond < question.minBond) {
            revert BondTooLow();
        }

        question.minBond = newBond * 2; // TODO: sqrt(value)*2)^2

        bonds[questionId][msg.sender] = newBond;

        answer.response = response;
        answer.responder = msg.sender;
        answer.historyHash = keccak256(
            abi.encodePacked(
                answer.historyHash,
                keccak256(abi.encodePacked(response, msg.sender, newBond))
            )
        );
    }

    /// @inheritdoc IBondedOracle
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
            // payable(answer.responder).transfer(question.bounty);
        }
    }

    ///  TODO: need to also add a fee for bonding an answer
    /// @inheritdoc IBondedOracle
    function reclaimBond(
        uint256 questionId,
        bytes32 response,
        bytes32[] memory previousHashes
    ) external {
        Question storage question = questions[questionId];
        Answer storage answer = answers[questionId];
        uint256 bond = bonds[questionId][msg.sender];

        if (question.contentHash == 0) {
            revert QuestionDoesNotExist();
        }

        if (answer.finalizedTime == 0) {
            revert AnswerNotFinalized();
        }

        // Verify the msg.sender's hashed data exists in the previousHashes list
        bytes32 senderHash = keccak256(abi.encodePacked(response, msg.sender, bond));
        bool found = false;
        for (uint256 i = 0; i < previousHashes.length; i++) {
            if (previousHashes[i] == senderHash) {
                found = true;
                break;
            }
        }

        if (!found) {
            revert NotFound();
        }

        bytes32 recomputedHash = recomputeHistoryHash(previousHashes);
        if (recomputedHash != answer.historyHash) {
            revert InvalidHistoryHash();
        }

        delete bonds[questionId][msg.sender];
        if (response == answer.response) {
            EncumberedToken(question.slashableAsset).release(msg.sender, bond);
        }
    }

    ///  TODO: need to also add a fee for bonding an answer
    /// @inheritdoc IBondedOracle
    function slashBond(
        uint256 questionId,
        bytes32 response,
        address responder,
        bytes32[] memory previousHashes
    ) external {
        Question storage question = questions[questionId];
        Answer storage answer = answers[questionId];
        uint256 bond = bonds[questionId][responder];

        if (question.contentHash == 0) {
            revert QuestionDoesNotExist();
        }

        if (answer.finalizedTime == 0) {
            revert AnswerNotFinalized();
        }

        // Verify the responder's hashed data exists in the previousHashes list
        bytes32 responderHash = keccak256(abi.encodePacked(response, responder, bond));
        bool found = false;
        for (uint256 i = 0; i < previousHashes.length; i++) {
            if (previousHashes[i] == responderHash) {
                found = true;
                break;
            }
        }

        if (!found) {
            revert NotFound();
        }

        bytes32 recomputedHash = recomputeHistoryHash(previousHashes);
        if (recomputedHash != answer.historyHash) {
            revert InvalidHistoryHash();
        }

        delete bonds[questionId][responder];
        if (response != answer.response) {
            EncumberedToken(question.slashableAsset).slash(responder, bond);
        }
    }

    /// @inheritdoc IBondedOracle
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
        if (amount > 0) {
            payable(msg.sender).transfer(amount);
        }
    }

    function recomputeHistoryHash(bytes32[] memory previousHashes) public pure returns (bytes32) {
        bytes32 currentHash = bytes32(0);
        for (uint256 i = 0; i < previousHashes.length; i++) {
            currentHash = keccak256(abi.encodePacked(currentHash, previousHashes[i]));
        }

        return currentHash;
    }
}
