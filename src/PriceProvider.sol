pragma solidity ^0.8.22;

import "openzeppelin-upgradeable/access/OwnableUpgradeable.sol";

interface IFunctionsConsumer {
    function s_lastResponse() external view returns (bytes memory);
    function latestTimestamp() external view returns (uint256 lastUpdated);
}

interface IChronicle {
    function readWithAge() external view returns (uint256, uint256);
}

interface IPriceProvider {
    function getPrice() external view returns (uint256);
}

contract PriceProvider is Initializable, OwnableUpgradeable, IPriceProvider {
    IFunctionsConsumer public consumer;
    uint256 public timeTolerance;

    error SourceDataStale();

    constructor() {
        _disableInitializers();
    }

    function initialize(address _functionsConsumer, uint256 _timeTolerance) public initializer {
        __Ownable_init();
        consumer = IFunctionsConsumer(_functionsConsumer);
        timeTolerance = _timeTolerance;
    }

    function setTimeTolerance(uint256 newTimeTolerance) public onlyOwner {
        timeTolerance = newTimeTolerance;
    }

    function getPrice() public virtual view returns (uint256) {
        if (consumer.latestTimestamp() < block.timestamp - timeTolerance) revert SourceDataStale();
        return uint256(bytes32(consumer.s_lastResponse()));
    }

    uint256[48] __gap;
}

contract PriceProviderV2 is PriceProvider {
    enum PriceStrategy {
        CLFunctionThenFallback
    }

    enum SourceType {
        ChainlinkFunctionsConsumer,
        ChronicleDataFeed
    }

    struct Source {
        address source;
        SourceType sourceType;
        bool enabled;
    }

    Source public chainlinkSource;
    Source public chronicleSource;

    error UnexpectedSourceType();
    error NoSources();
    error NoStrategy();
    error NotOwner();
    error SourceDisabled();

    enum Error {
        NoError,
        UnexpectedSourceType,
        SourceDataStale,
        SourceDisabled,
        NoSources,
        NoStrategy
    }

    constructor() {
        _disableInitializers();
    }

    function initializeV2(Source memory _chronicleSource) public reinitializer(2) onlyOwner {
        chainlinkSource = Source({
            source: address(consumer),
            sourceType: SourceType.ChainlinkFunctionsConsumer,
            enabled: true
        });

        chronicleSource = _chronicleSource;
    }

    function tryGetChainlinkFunctionsPrice(Source memory source) internal view returns (Error, uint256) {
        if (source.sourceType != SourceType.ChainlinkFunctionsConsumer) return (Error.UnexpectedSourceType, 0);
        if (!source.enabled) return (Error.SourceDisabled, 0);

        IFunctionsConsumer consumer = IFunctionsConsumer(source.source);
        if (consumer.latestTimestamp() < block.timestamp - timeTolerance) return (Error.SourceDataStale, 0);

        return (Error.NoError, uint256(bytes32(consumer.s_lastResponse())));
    }

    function tryGetChroniclePrice(Source memory source) internal view returns (Error, uint256) {
        if (source.sourceType != SourceType.ChronicleDataFeed) return(Error.UnexpectedSourceType, 0);
        if (!source.enabled) return (Error.SourceDisabled, 0);

        IChronicle feed = IChronicle(source.source);
        (uint256 val, uint256 age) = feed.readWithAge();
        if (age < block.timestamp - timeTolerance) return (Error.SourceDataStale, 0);

        return (Error.NoError, val);
    }

    function setChainlinkSourceEnabled(bool enable) external onlyOwner {
        chainlinkSource.enabled = enable;
    }

    function setChronicleSourceEnabled(bool enable) external onlyOwner {
        chronicleSource.enabled = enable;
    }

    function tryGetSourcePrice(Source memory source) internal view returns (Error, uint256) {
        if (source.sourceType == SourceType.ChainlinkFunctionsConsumer) {
            return tryGetChainlinkFunctionsPrice(source);
        } else if (source.sourceType == SourceType.ChronicleDataFeed) {
            return tryGetChroniclePrice(source);
        } else revert();
    }

    function handleError(Error err) internal pure {
        if (err == Error.UnexpectedSourceType) {
            revert UnexpectedSourceType();
        } else if (err == Error.SourceDataStale) {
            revert SourceDataStale();
        } else if (err == Error.NoSources) {
            revert NoSources();
        } else if (err == Error.NoStrategy) {
            revert NoStrategy();
        } else if (err == Error.SourceDisabled) {
            revert SourceDisabled();
        }
    }

    function isError(Error err) internal pure returns (bool _isError) {
        _isError = true;
        if (err == Error.NoError) {
            _isError = false;
        }
    }

    function getCLFunctionThenFallbackPrice() public view returns (uint256 data) {
        Error clErr;
        Error fallbackErr;

        uint256 clResponse;
        uint256 fallbackResponse;

        (clErr, clResponse) = tryGetChainlinkFunctionsPrice(chainlinkSource);
        (fallbackErr, fallbackResponse) = tryGetChroniclePrice(chronicleSource);

        if (isError(clErr)) {
            if (isError(fallbackErr)) {
                revert NoSources();
            }
            return fallbackResponse;
        } else {
            if (isError(fallbackErr)) {
                return clResponse;
            } else {
                return (clResponse + fallbackResponse) / 2;
            }
        }
    }

    function getPriceWithStrategy(PriceStrategy strat) external view returns (uint256 data) {
        if (strat == PriceStrategy.CLFunctionThenFallback) {
            return getCLFunctionThenFallbackPrice();
        } else revert NoStrategy();
    }

    function getPrice() public virtual override view returns (uint256 data) {
        return getCLFunctionThenFallbackPrice();
    }
}
