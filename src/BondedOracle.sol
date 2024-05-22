// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.20;

contract BondedOracle {
    error QuestionAlreadyExists();
    error QuestionDoesNotExist();
    error FinalizationDeadlineNotReached();
    error OpeningTimeNotReached();
    error BondTooLow();
    error InvalidExpiry();
    error InvalidAnswerer();
    error AnswerNotFinalized();
    error AnswerAlreadyFinalized();

    struct Question {
        uint256 openingTime;
        address asker;
        bytes32 contentHash;
        uint256 expiry;
        uint256 bounty;
        uint256 minBond;
    }

    struct Answer {
        bytes32 response;
        address responder;
        uint256 finalizedTime;
        bytes32 historyHash;
    }

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

        if (questions[questionId].contentHash != 0) {
            revert QuestionAlreadyExists();
        }

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
        /// TODO: Decide on the criteria to cancel a question
    }

    /// TODO: need to implement virtual function for calculating required bond
    function provideAnswer(uint256 questionId, bytes32 response) external payable {
        Question storage question = questions[questionId];
        Answer storage answer = answers[questionId];

        if (question.contentHash == 0) {
            revert QuestionDoesNotExist();
        }
        if (block.timestamp < question.openingTime) {
            revert OpeningTimeNotReached();
        }
        if (msg.value <= question.minBond) {
            revert BondTooLow();
        }

        answer.response = response;
        answer.responder = msg.sender;
        question.minBond = msg.value;

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
        /// TODO: assess answer and send back bond

        /// TODO: Events need to be able to re-create chain of history of the answers so this function can re-create and assess
        /// if the user can claim their bond back and mark them as claimed
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
        delete question.bounty;
        payable(msg.sender).transfer(amount);
    }
}
