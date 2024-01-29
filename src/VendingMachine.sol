// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "openzeppelin-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "openzeppelin-upgradeable/access/AccessControlUpgradeable.sol";
import "openzeppelin/metatx/ERC2771Context.sol";
import "forge-std/console.sol";

import "src/NumToken.sol";

uint constant REQUEST_LOOP_LENGTH = 50;

contract VendingMachine is Initializable, ERC2771Context {

    enum BulkOrderState {
        OPEN,
        CLOSED,
        MINTED,
        FULFILLED
    }

    struct BulkOrder {
        uint256 stableTokenReceived;
        uint256 etfTokenReceived;
        uint256 etfTokenAmountMinted;
        mapping(uint256 => Request) requests;
        uint256 requestCount;
        BulkOrderState state;
        uint256 openedTimestamp;
    }

    struct Request {
        bool isMint;
        address payable buyer;
        uint256 stableTokenAmount;
        uint256 etfTokenAmount;
        uint256 requestedAt;
    }

    mapping(uint256 => BulkOrder) public bulkOrders;
    uint256 public activeBulkOrder;
    bool isBulkOrderActive = false;

    IERC20Upgradeable public stableToken;
    NumToken public etfToken;

    address payable public managerWallet;
    address payable public feeWallet;

    uint16 public mintingFeeBp;

    event MintRequested(uint256 indexed bulkOrderId, uint256 indexed requestId);

    event RedeemRequested(uint256 indexed bulkOrderId, uint256 indexed requestId);

    event BulkOrderOpened(uint256 indexed orderId);
    event BulkOrderClosed(uint256 indexed orderId);
    event BulkOrderMinted(uint256 indexed orderId, uint256 mintedAmount);
    event BulkOrderFulfilled(uint256 indexed orderId);

    modifier onlyManager() {
        require(_msgSender() == managerWallet, "only manager");
        _;
    }

    modifier onlyBulkOrderActive() {
        if (!isBulkOrderActive) {
            revert("bulk orders are not open");
        }
        _;
    }

    modifier onlyMatureBulkOrder(uint256 bulkOrderId) {
        require(
            block.timestamp - bulkOrders[bulkOrderId].openedTimestamp >= 1 days,
            "too soon to create new bulk order"
        );
        _;
    }

    constructor(address forwarder) ERC2771Context(forwarder) {}

    function bulkOrderInnerOrder(uint256 bulkOrderId, uint256 innerOrderId) public view returns (Request memory request) {
        request = bulkOrders[bulkOrderId].requests[innerOrderId];
    }

    function initialize(IERC20Upgradeable _stableToken, NumToken _etfToken, address payable _managerWallet, address payable _feeWallet) public initializer {
        stableToken = _stableToken;
        etfToken = _etfToken;
        managerWallet = _managerWallet;
        feeWallet = _feeWallet;
        isBulkOrderActive = true;
        bulkOrders[activeBulkOrder].openedTimestamp = block.timestamp;
    }

    function setMintingFee(uint16 newMintingFee) public onlyManager {
        require(newMintingFee <= 10000, "minting fee is capped at 10k bp");
        mintingFeeBp = newMintingFee;
    }

    function _queueRequest(Request memory request) internal returns (uint256 index) {
        BulkOrder storage bulk = bulkOrders[activeBulkOrder];

        bulk.stableTokenReceived += request.stableTokenAmount;
        bulk.etfTokenReceived += request.etfTokenAmount;
        bulk.requests[bulk.requestCount++] = request;
        index = bulk.requestCount;
    }

    function requestMint(uint256 stableTokenAmount) public onlyBulkOrderActive {
        uint256 mintFee = stableTokenAmount * mintingFeeBp / 10000;
        require(
            stableToken.transferFrom(_msgSender(), address(this), stableTokenAmount - mintFee),
            "transfer to contract failed"
        );
        require(
            stableToken.transferFrom(_msgSender(), feeWallet, mintFee),
            "transfer to fee wallet failed"
        );

        // TODO: queue mint

        uint256 requestIndex = _queueRequest(Request({
            isMint: true,
            buyer: payable(_msgSender()),
            stableTokenAmount: stableTokenAmount - mintFee,
            etfTokenAmount: 0,
            requestedAt: block.timestamp
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
            requestedAt: block.timestamp
        }));

        emit RedeemRequested(activeBulkOrder, requestId); 
    }

    function _createNewBulkOrder() internal onlyMatureBulkOrder(activeBulkOrder) {
        activeBulkOrder++;
        emit BulkOrderOpened(activeBulkOrder);

        bulkOrders[activeBulkOrder].state = BulkOrderState.OPEN;
        bulkOrders[activeBulkOrder].openedTimestamp = block.timestamp;
    }

    function closeBulkOrder(uint256 bulkOrderId) public onlyManager onlyMatureBulkOrder(bulkOrderId) {
        BulkOrder storage order = bulkOrders[bulkOrderId];
        require(order.state == BulkOrderState.OPEN, "Invalid bulk order state");
        
        stableToken.transfer(_msgSender(), order.stableTokenReceived);
        order.state = BulkOrderState.CLOSED;
        emit BulkOrderClosed(bulkOrderId);

        _createNewBulkOrder();
    }

    function mintForBulkOrder(uint256 bulkOrderId, uint256 etfTokensObtained) public onlyManager {
        BulkOrder storage order = bulkOrders[bulkOrderId];
        require(order.state == BulkOrderState.CLOSED, "Invalid bulk order state");
        order.etfTokenAmountMinted = etfTokensObtained;
        etfToken.mint(_msgSender(), etfTokensObtained);

        order.state = BulkOrderState.MINTED;
        emit BulkOrderMinted(bulkOrderId, etfTokensObtained);
    }

    function markBulkOrderFulfilled(uint256 bulkOrderId) public onlyManager {
        BulkOrder storage order = bulkOrders[bulkOrderId]; 
        require(order.state == BulkOrderState.MINTED, "Invalid bulk order state");

        emit BulkOrderFulfilled(bulkOrderId);
        order.state = BulkOrderState.FULFILLED;
    }

    uint256[40] internal _padding;
}