// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "src/pricing/interfaces/IFunctionsConsumer.sol";

contract FakeConsumer is IFunctionsConsumer {
    bytes public s_lastResponse;
    uint256 public latestTimestamp;

    function setResponse(bytes calldata response) public {
        s_lastResponse = response;
        latestTimestamp = block.timestamp;
    }
}