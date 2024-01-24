// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "openzeppelin-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import "openzeppelin/metatx/ERC2771Context.sol";

import "src/NumToken.sol";

contract VendingMachine is Initializable, ERC2771Context {
    struct BulkOrder {
        uint256 stableTokenReceived;
        uint256 etfTokenReceived;
        mapping(uint256 => Request) requests;
        uint256 requestCount;
        bool executed;
    }

    struct Request {
        bool isMint;
        address payable buyer;
        uint256 stableTokenAmount;
        uint256 etfTokenAmount;
        uint256 requestedAt;
        uint256 fulfilledAt;
    }

    mapping(uint256 => BulkOrder) public bulkOrders;
    uint256 public activeBulkOrder;

    IERC20Upgradeable public stableToken;
    NumToken public etfToken;

    bool public isBulkOrderActive = false;

    address payable public managerWallet;
    address payable public feeWallet;

    uint16 public mintingFeeBp;

    event MintRequested(uint256 indexed bulkOrderId, uint256 indexed requestId);
    event MintFulfilled(uint256 indexed bulkOrderId, uint256 indexed requestId);

    event RedeemRequested(uint256 indexed bulkOrderId, uint256 indexed requestId);
    event RedeemFulfilled(uint256 indexed bulkOrderId, uint256 indexed requestId);

    event BulkOrderClosed(uint256 indexed orderId);
    event BulkOrderOpened(uint256 indexed orderId);
    error BulkOrderNotOpen();

    modifier onlyManager() {
        assert(_msgSender() == managerWallet);
        _;
    }

    modifier onlyBulkOrderActive() {
        if (!isBulkOrderActive) {
            revert BulkOrderNotActive();
        }
        _;
    }

    constructor(address forwarder) ERC2771Context(forwarder) {}

    function initialize(IERC20Upgradeable _stableToken, NumToken _etfToken, address payable _managerWallet, address payable _feeWallet) public initializer {
        stableToken = _stableToken;
        etfToken = _etfToken;
        managerWallet = _managerWallet;
        feeWallet = _feeWallet;
        isBulkOrderActive = true;
    }

    function setMintingFee(uint16 newMintingFee) public onlyManager {
        assert(newMintingFee <= 10000);
        mintingFeeBp = newMintingFee;
    }

    /**
     * @note Batch up to 50 requests per bulk order to limit execution loop runtime
     */
    function _queueRequest(Request memory request) internal returns (uint256 index) {
        if (bulkOrders[activeBulkOrder].requestCount >= 50) {
            activeBulkOrder++;
        }
        BulkOrder storage bulk = bulkOrders[activeBulkOrder];

        bulk.stableTokenReceived += request.stableTokenAmount;
        bulk.etfTokenReceived += request.etfTokenAmount;
        bulk.requests[++bulk.requestCount] = request;
        index = bulk.requests.length;
    }

    function requestMint(uint256 stableTokenAmount) public onlyBulkOrderActive {
        uint256 mintFee = stableTokenAmount * mintingFeeBp / 10000;
        assert(
            stableToken.transferFrom(_msgSender(), managerWallet, stableTokenAmount - mintFee)
        );
        assert(
            stableToken.transferFrom(_msgSender(), feeWallet, mintFee)
        );

        // TODO: queue mint

        uint256 requestIndex = _queueRequest(Request({
            isMint: true,
            buyer: payable(_msgSender()),
            stableTokenAmount: stableTokenAmount - mintFee,
            etfTokenAmount: 0,
            requestedAt: block.timestamp,
            fulfilledAt: 0
        }));
        emit MintRequested(activeBulkOrder, requestIndex);
    }

    function requestRedeem(uint256 etfTokenAmount) public onlyBulkOrderActive {
        etfToken.burn(_msgSender(), etfTokenAmount);

        // TODO: queue redeem

        uint256 requestId = _queueRequest(Request({
            isMint: false,
            buyer: payable(_msgSender()),
            stableTokenAmount: 0,
            etfTokenAmount: etfTokenAmount,
            requestedAt: block.timestamp,
            fulfilledAt: 0
        }));

        emit RedeemRequested(activeBulkOrder, requestId); 
    }

    function closeAndExecuteBulkOrder(uint256 bulkOrderId, uint256 stableTokenAmountObtained, uint256 etfTokenAmountToMint) public onlyManager {
        BulkOrder storage order = bulkOrders[bulkOrderId];
        assert(!order.executed);
        require(
            stableToken.balanceOf(address(this)) >= stableTokenAmountObtained
        );
        etfToken.mint(address(this), etfTokenAmountToMint);

        for (uint idx = 0; idx < order.requestCount; idx++) {
            Request storage request = order.requests[idx];
            if (request.isMint) {
                uint256 etfTokenAmount = etfTokenAmountToMint * request.stableTokenAmount / order.stableTokenReceived;
                require(
                    etfToken.transfer(request.buyer, etfTokenAmount)
                );
                emit MintFulfilled(bulkOrderId, idx);
            } else {
                uint256 stableTokenAmount = stableTokenAmountObtained * request.etfTokenAmount / etfTokenAmountToMint;
                require(
                    stableToken.transfer(request.buyer, stableTokenAmount)
                );
                emit RedeemFulfilled(bulkOrderId, idx);
            }
            request.fulfilledAt = block.timestamp;
        } 

        order.executed = true;
        emit BulkOrderClosed(bulkOrderId);
    }

    uint256[40] internal _padding;
}