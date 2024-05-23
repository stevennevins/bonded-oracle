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
}
