pragma solidity ^0.8.22;

interface IChronicle {
    function readWithAge() external view returns (uint256, uint256);
}
