// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.19;

import "src/pricing/interfaces/IChronicle.sol";

contract FakeChronicle is IChronicle {
    uint256 public latestResponse;
    uint256 public latestTimestamp;

    function setResponse(uint256 response) public {
        latestResponse = response;
        latestTimestamp = block.timestamp;
    }

    function readWithAge() public view returns (uint256, uint256) {
        return (latestResponse, latestTimestamp);
    }
}
