pragma solidity ^0.8.22;

import "./interfaces/IFunctionsConsumer.sol";
import "./interfaces/IPriceProvider.sol";
import "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";


contract PriceProvider is Initializable, OwnableUpgradeable, IPriceProvider {
    IFunctionsConsumer public consumer;
    uint256 public timeTolerance;

    error SourceDataStale();

    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address _functionsConsumer, uint256 _timeTolerance) public initializer {
        __Ownable_init();
        transferOwnership(admin);
        consumer = IFunctionsConsumer(_functionsConsumer);
        timeTolerance = _timeTolerance;
    }

    function setTimeTolerance(uint256 newTimeTolerance) public onlyOwner {
        timeTolerance = newTimeTolerance;
    }

    function getPrice() public virtual view returns (uint256) {
        if (consumer.latestTimestamp() + timeTolerance < block.timestamp) revert SourceDataStale();
        return uint256(bytes32(consumer.s_lastResponse()));
    }

    uint256[48] __gap;
}

