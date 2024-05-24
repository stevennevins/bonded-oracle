// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.20;

import {IBondedOracleEventsAndErrors} from "./IBondedOracleEventsAndErrors.sol";

interface IBondedOracle is IBondedOracleEventsAndErrors {
    /**
     * @notice Represents a question asked in the oracle system.
     * @param openingTime The time when the question becomes open for answers.
     * @param asker The address of the user who asked the question.
     * @param contentHash The hash of the question content.
     * @param expiry The time after which the question expires and can no longer be answered.
     * @param bounty The bounty amount offered for answering the question.
     * @param minBond The minimum bond required to answer the question.
     */
    struct Question {
        uint256 openingTime;
        address asker;
        bytes32 contentHash;
        uint256 expiry;
        uint256 bounty;
        uint256 minBond;
    }

    /**
     * @notice Represents an answer provided in the oracle system.
     * @param response The response to the question.
     * @param responder The address of the user who provided the answer.
     * @param finalizedTime The time when the answer was finalized.
     * @param historyHash The hash of the answer history.
     */
    struct Answer {
        bytes32 response;
        address responder;
        uint256 finalizedTime;
        bytes32 historyHash;
    }

    /**
     * @notice Returns the ID of the next question to be created.
     * @return The ID of the next question.
     */
    function nextQuestionId() external view returns (uint256);

    /**
     * @notice Returns the observer address for a given question ID.
     * @param questionId The ID of the question.
     * @return The address of the observer.
     */
    function observers(uint256 questionId) external view returns (address);

    /**
     * @notice Returns the details of a question for a given question ID.
     * @param questionId The ID of the question.
     * @return openingTime The time when the question becomes open for answers.
     * @return asker The address of the user who asked the question.
     * @return contentHash The hash of the question content.
     * @return expiry The time after which the question expires and can no longer be answered.
     * @return bounty The bounty amount offered for answering the question.
     * @return minBond The minimum bond required to answer the question.
     */
    function questions(
        uint256 questionId
    ) external view returns (uint256, address, bytes32, uint256, uint256, uint256);

    /**
     * @notice Returns the details of an answer for a given question ID.
     * @param questionId The ID of the question.
     * @return response The response to the question.
     * @return responder The address of the user who provided the answer.
     * @return finalizedTime The time when the answer was finalized.
     * @return historyHash The hash of the answer history.
     */
    function answers(uint256 questionId) external view returns (bytes32, address, uint256, bytes32);

    /**
     * @notice Returns the bond amount for a given question ID and claimer address.
     * @param questionId The ID of the question.
     * @param claimer The address of the user claiming the bond.
     * @return The bond amount.
     */
    function bonds(uint256 questionId, address claimer) external view returns (uint256);

    /**
     * @notice Sets the observer for a given question.
     * @dev Only the asker of the question can set the observer.
     * @param _questionId The ID of the question for which the observer is being set.
     * @param observer The address of the observer to be set.
     */
    function setObserver(uint256 _questionId, address observer) external;

    /**
     * @notice Requests an answer for a given question.
     * @dev The question will be open for answers after the specified opening time.
     * @param openingTime The time when the question becomes open for answers.
     * @param expiry The time after which the question expires and can no longer be answered.
     * @param minBond The minimum bond required to answer the question.
     * @param question The content of the question.
     * @return The ID of the newly created question.
     */
    function requestAnswer(
        uint32 openingTime,
        uint32 expiry,
        uint256 minBond,
        string memory question
    ) external payable returns (uint256);

    /**
     * @notice Cancels a request for a given question.
     * @dev Only the asker of the question can cancel the request.
     * @param questionId The ID of the question to be canceled.
     */
    function cancelRequest(uint256 questionId) external;

    /**
     * @notice Provides an answer to a given question.
     * @dev The sender must provide a bond that meets or exceeds the minimum bond required for the question.
     * @param questionId The ID of the question to be answered.
     * @param response The response to the question.
     */
    function provideAnswer(uint256 questionId, bytes32 response) external payable;

    /**
     * @notice Finalizes the answer for a given question.
     * @dev The answer can only be finalized after the question's expiry time has passed.
     * @param questionId The ID of the question to finalize the answer for.
     */
    function finalizeAnswer(uint256 questionId) external;

    /**
     * @notice Reclaims the bond for a given question and response.
     * @dev The sender must provide the correct response and previous hashes to reclaim the bond.
     * @param questionId The ID of the question for which the bond is being reclaimed.
     * @param response The response provided by the sender.
     * @param previousHashes The list of previous hashes to verify the sender's response.
     */
    function reclaimBond(
        uint256 questionId,
        bytes32 response,
        bytes32[] memory previousHashes
    ) external;

    /**
     * @notice Withdraws the bounty for a given question.
     * @dev The sender must be the responder of the finalized answer.
     * @param questionId The ID of the question for which the bounty is being withdrawn.
     */
    function withdrawBounty(uint256 questionId) external;
}
