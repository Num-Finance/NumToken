pragma solidity ^0.8.22;

interface IPriceProvider {
    function getPrice() external view returns (uint256);
}
