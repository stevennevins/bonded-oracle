// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.20;

import {IBondedOracleEventsAndErrors} from "./IBondedOracleEventsAndErrors.sol";

interface IBondedOracle is IBondedOracleEventsAndErrors {
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

    function nextQuestionId() external view returns (uint256);

    function questions(
        uint256 questionId
    )
        external
        view
        returns (
            uint256 openingTime,
            address asker,
            bytes32 contentHash,
            uint256 expiry,
            uint256 bounty,
            uint256 minBond
        );

    function answers(
        uint256 questionId
    )
        external
        view
        returns (bytes32 response, address responder, uint256 finalizedTime, bytes32 historyHash);

    function claimedBonds(uint256 questionId, address claimer) external view returns (uint256);

    function postQuestion(
        uint32 openingTime,
        uint32 expiry,
        uint256 minBond,
        string memory question
    ) external payable returns (uint256);

    function cancelQuestion(uint256 questionId) external;

    function provideAnswer(uint256 questionId, bytes32 response) external payable;

    function finalizeAnswer(uint256 questionId) external;

    function reclaimBond(uint256 questionId) external;

    function withdrawBounty(uint256 questionId) external;
}
