// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.20;

interface IBondedOracleEventsAndErrors {
    error QuestionDoesNotExist();
    error FinalizationDeadlineNotReached();
    error OpeningTimeNotReached();
    error BondTooLow();
    error NotCancellable();
    error InvalidExpiry();
    error InvalidAnswerer();
    error AnswerNotFinalized();
    error AnswerAlreadyFinalized();
    error AnswerPeriodClosed();
    error NotAuthorized();
    error BountyAlreadyClaimed();
    error NotFound();
    error InvalidHistoryHash();
    error ObserverNotAssignable();
}
