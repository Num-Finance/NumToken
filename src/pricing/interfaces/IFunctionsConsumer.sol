pragma solidity ^0.8.22;

interface IFunctionsConsumer {
    function s_lastResponse() external view returns (bytes memory);
    function latestTimestamp() external view returns (uint256 lastUpdated);
}
