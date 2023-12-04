/// SPDX-Licensse-Indentifier: Unlicensed
pragma solidity ^0.8.15;

import "openzeppelin-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import "openzeppelin/metatx/ERC2771Context.sol";

import "src/NumToken.sol";

contract VendingMachine is Initializable, ERC2771Context {
    struct Request {
        bool isMint;
        uint256 index;
        address payable buyer;
        uint256 stableTokenAmount;
        uint256 etfTokenAmount;
        uint256 requestedAt;
        uint256 fulfilledAt;
        string ipfsLink;
    }
    mapping(bytes32 => Request) public requests;
    bytes32[] public requestOrdering;
    uint256 public latestFulfilledRequest;
    uint256 public latestRequest;

    IERC20Upgradeable public stableToken;
    NumToken public etfToken;

    address payable public managerWallet;
    address payable public feeWallet;

    uint16 public mintingFeeBp;

    event MintRequested(bytes32 indexed requestId);
    event MintFulfilled(bytes32 indexed requestId);

    event RedeemRequested(bytes32 indexed requestId);
    event RedeemFulfilled(bytes32 indexed requestId);

    modifier onlyManager() {
        assert(_msgSender() == managerWallet);
        _;
    }

    constructor(address forwarder) ERC2771Context(forwarder) {}

    function initialize(IERC20Upgradeable _stableToken, NumToken _etfToken, address payable _managerWallet, address payable _feeWallet) public initializer {
        stableToken = _stableToken;
        etfToken = _etfToken;
        managerWallet = _managerWallet;
        feeWallet = _feeWallet;
    }

    function setMintingFee(uint16 newMintingFee) public onlyManager {
        assert(newMintingFee <= 10000);
        mintingFeeBp = newMintingFee;
    }

    function _queueRequest(Request memory request) internal returns (bytes32) {
        bytes32 id = keccak256(abi.encode(request));
        requests[id] = request;
        requestOrdering.push(id);
        latestRequest++;
        return id;
    }

    function requestMint(uint256 stableTokenAmount) public {
        uint256 mintFee = stableTokenAmount * mintingFeeBp / 10000;
        assert(
            stableToken.transferFrom(_msgSender(), managerWallet, stableTokenAmount - mintFee)
        );
        assert(
            stableToken.transferFrom(_msgSender(), feeWallet, mintFee)
        );

        // TODO: queue mint

        bytes32 requestId = _queueRequest(Request({
            isMint: true,
            index: latestRequest++,
            buyer: payable(_msgSender()),
            stableTokenAmount: stableTokenAmount - mintFee,
            etfTokenAmount: 0,
            requestedAt: block.timestamp,
            fulfilledAt: 0,
            ipfsLink: ""
        }));
        emit MintRequested(requestId);
    }

    function executeMint(bytes32 requestId, uint256 etfTokenAmount, string calldata ipfsLink) public onlyManager {
        Request storage request = requests[requestId];
        assert(request.fulfilledAt == 0);
        assert(request.isMint);

        etfToken.mint(request.buyer, etfTokenAmount);
        request.fulfilledAt = block.timestamp;
        request.etfTokenAmount = etfTokenAmount;
        request.ipfsLink = ipfsLink;

        latestFulfilledRequest = request.index;

        emit MintFulfilled(requestId);
    }

    function requestRedeem(uint256 etfTokenAmount) public {
        etfToken.burn(_msgSender(), etfTokenAmount);

        // TODO: queue redeem

        bytes32 requestId = _queueRequest(Request({
            isMint: false,
            index: latestRequest++,
            buyer: payable(_msgSender()),
            stableTokenAmount: 0,
            etfTokenAmount: etfTokenAmount,
            requestedAt: block.timestamp,
            fulfilledAt: 0,
            ipfsLink: ""
        }));

        emit RedeemRequested(requestId); 
    }

    function executeRedeem(bytes32 requestId, uint256 stableTokenAmount, string calldata ipfsLink) public onlyManager {
        Request storage request = requests[requestId];
        assert(request.fulfilledAt == 0);
        assert(request.index == latestFulfilledRequest + 1);
        assert(!request.isMint);

        assert(stableToken.transferFrom(managerWallet, request.buyer, stableTokenAmount));
        request.fulfilledAt = block.timestamp;
        request.stableTokenAmount = stableTokenAmount;
        request.ipfsLink = ipfsLink;

        latestFulfilledRequest = request.index;

        emit RedeemFulfilled(requestId);
    }

    uint256[40] internal _padding;
}