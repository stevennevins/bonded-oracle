// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.20;

interface IBondedOracleEventsAndErrors {
    /**
     * @notice Thrown when a question does not exist.
     */
    error QuestionDoesNotExist();

    /**
     * @notice Thrown when the finalization deadline has not been reached.
     */
    error FinalizationDeadlineNotReached();

    /**
     * @notice Thrown when the opening time for a question has not been reached.
     */
    error OpeningTimeNotReached();

    /**
     * @notice Thrown when the provided bond is too low.
     */
    error BondTooLow();

    /**
     * @notice Thrown when a question cannot be cancelled.
     */
    error NotCancellable();

    /**
     * @notice Thrown when the expiry time for a question is invalid.
     */
    error InvalidExpiry();

    /**
     * @notice Thrown when the answerer is invalid.
     */
    error InvalidAnswerer();

    /**
     * @notice Thrown when an answer has not been finalized.
     */
    error AnswerNotFinalized();

    /**
     * @notice Thrown when an answer has already been finalized.
     */
    error AnswerAlreadyFinalized();

    /**
     * @notice Thrown when the answer period for a question is closed.
     */
    error AnswerPeriodClosed();

    /**
     * @notice Thrown when the caller is not authorized to perform an action.
     */
    error NotAuthorized();

    /**
     * @notice Thrown when the bounty for a question has already been claimed.
     */
    error BountyAlreadyClaimed();

    /**
     * @notice Thrown when a required item is not found.
     */
    error NotFound();

    /**
     * @notice Thrown when the history hash is invalid.
     */
    error InvalidHistoryHash();

    /**
     * @notice Thrown when an observer cannot be assigned to a question.
     */
    error ObserverNotAssignable();
}
