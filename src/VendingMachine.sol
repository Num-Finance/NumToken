// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "openzeppelin-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "openzeppelin/access/AccessControl.sol";

import "src/NumToken.sol";
import "src/KYCMapper.sol";

/**
 * Num ETF Token Vending Machine
 * @author Felipe Buiras
 * @dev This contract helps with the collection of buy/sell orders for Num ETF Tokens, which are executed by a human operator.
 * @dev Individual orders are collected into a usually daily "Bulk Order" and executed in batches.
 * @dev **** THIS CONTRACT DOES NOT SUPPORT FEE-ON-TRANSFER TOKENS AS THE STABLE LEG ****
 */
contract VendingMachine is AccessControl {
    /**
     * @dev Enum describing the current state of a Bulk order
     */
    enum BulkOrderState {
        OPEN,
        CLOSED,
        MINTED,
        FULFILLED
    }

    /**
     * @dev This struct is both represented here and in an offchain DB for easy reference
     */
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

    /**
     * @dev Role responsible for management actions on this contract
     */
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    mapping(uint256 => BulkOrder) public bulkOrders;
    uint256 public activeBulkOrder;

    IERC20Upgradeable public stableToken;
    NumToken public etfToken;

    /**
     * This contract is responsible for keeping track of the KYC Whitelist status of any address.
     * @dev Calls should be made to this contract on all client-facing functions.
     */
    KYCMapper public mapper;

    /**
     * @dev All fees collected from user requests are to be sent to this wallet.
     */
    address payable public feeWallet;

    /**
     * This setting allows Num to collect fees for minting Num ETF Tokens.
     * @dev Expressed in *basis points*, may be changed by managers
     */
    uint16 public mintingFeeBp;

    event MintRequested(uint256 indexed bulkOrderId, uint256 indexed requestId);
    event RedeemRequested(uint256 indexed bulkOrderId, uint256 indexed requestId);

    event BulkOrderOpened(uint256 indexed orderId);
    event BulkOrderClosed(uint256 indexed orderId);
    event BulkOrderMinted(uint256 indexed orderId, uint256 mintedAmount);
    event BulkOrderFulfilled(uint256 indexed orderId);

    error InvalidBulkOrderStateTransition();
    error InvalidParameters();
    error FailedInternalTransfer();
    error AddressNotWhitelisted();
    error InvalidMintFee();

    modifier onlyWhitelisted(address who) {
        if (!mapper.isAddressWhitelisted(who)) {
          revert AddressNotWhitelisted();
        }
        _;
    }

    constructor(
      IERC20Upgradeable _stableToken,
      NumToken _etfToken,
      KYCMapper _mapper,
      address payable _managerWallet,
      address payable _feeWallet
    ) AccessControl() {
        stableToken = _stableToken;
        etfToken = _etfToken;
        feeWallet = _feeWallet;
        mapper = _mapper;
        bulkOrders[activeBulkOrder].openedTimestamp = block.timestamp;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MANAGER_ROLE, _managerWallet);
    }

    /**
     * @dev Returns an individual order by its Bulk Order and internal index, for offchain reference.
     */
    function bulkOrderInnerOrder(uint256 bulkOrderId, uint256 innerOrderId) public view returns (Request memory request) {
        request = bulkOrders[bulkOrderId].requests[innerOrderId];
    }

    /**
     * @dev Allows changing of the minting fee to be collected on mint requests.
     */
    function setMintingFee(uint16 newMintingFee) public onlyRole(MANAGER_ROLE) {
        if (newMintingFee > 10000) {
          revert InvalidParameters();
        }
        mintingFeeBp = newMintingFee;
    }

    /**
     * @dev Allows managers to change the destination wallet for collected fees.
     */
    function setFeeWallet(address payable _feeWallet) public onlyRole(MANAGER_ROLE) {
        feeWallet = _feeWallet;
    }

    /**
     * @dev Push a new request onto a bulk order. This updates its internal tracking.
     */
    function _queueRequest(Request memory request) internal returns (uint256 index) {
        BulkOrder storage bulk = bulkOrders[activeBulkOrder];
        index = bulk.requestCount;

        bulk.stableTokenReceived += request.stableTokenAmount;
        bulk.etfTokenReceived += request.etfTokenAmount;
        bulk.requests[bulk.requestCount++] = request;
    }

    /**
     * Request a new Num ETF Token minting operation.
     * @dev This function also collects minting fees for the operation, and subtracts them from the reported stable token amount.
     */
    function requestMint(uint256 stableTokenAmount, uint256 expectedMintFeeBp) public onlyWhitelisted(_msgSender()) {
        if (mintingFeeBp > expectedMintFeeBp) {
          revert InvalidMintFee();
        }
        uint256 mintFee = stableTokenAmount * mintingFeeBp / 10000;

        if (!stableToken.transferFrom(_msgSender(), address(this), stableTokenAmount - mintFee)) {
          revert FailedInternalTransfer();
        }

        if (mintFee != 0) {
          if (!stableToken.transferFrom(_msgSender(), feeWallet, mintFee)) {
            revert FailedInternalTransfer();
          }
        }

        uint256 requestIndex = _queueRequest(Request({
            isMint: true,
            buyer: payable(_msgSender()),
            stableTokenAmount: stableTokenAmount - mintFee,
            etfTokenAmount: 0,
            requestedAt: block.timestamp
        }));

        emit MintRequested(activeBulkOrder, requestIndex);
    }

    /**
     * Request a new Num ETF Token burning operation.
     * @dev Redeemal fees are to be charged by omitting some of the resulting tokens from the distributed amount.
     *      i.e. if the redeemal fee is 2% and the resulting stable tokens from the sale are 100, 98 should get distributed to the redeemer.
     * @dev Burns the redeemed ETF tokens on the spot, since there were no discussions on the possibility of a bulk order "getting stuck" and ths requiring refunds directly from the contract. Operations can always refund by minting replacement tokens and sending them over.
     */
    function requestRedeem(uint256 etfTokenAmount) public onlyWhitelisted(_msgSender()) {
        etfToken.burn(_msgSender(), etfTokenAmount);

        uint256 requestId = _queueRequest(Request({
            isMint: false,
            buyer: payable(_msgSender()),
            stableTokenAmount: 0,
            etfTokenAmount: etfTokenAmount,
            requestedAt: block.timestamp
        }));

        emit RedeemRequested(activeBulkOrder, requestId); 
    }

    /**
     * @dev Create a new bulk order. This does *not* change the currently active bulk order's state.
     */
    function _createNewBulkOrder() internal {
        activeBulkOrder++;
        emit BulkOrderOpened(activeBulkOrder);

        bulkOrders[activeBulkOrder].state = BulkOrderState.OPEN;
        bulkOrders[activeBulkOrder].openedTimestamp = block.timestamp;
    }

    /**
     * Close the currently active bulk order, allowing an oeprator to begin the order filling process.
     * @dev This creates a new bulk order so that requests can still come in, but end up in the next one.
     */
    function closeBulkOrder() public onlyRole(MANAGER_ROLE) {
        uint256 bulkOrderId = activeBulkOrder;
        BulkOrder storage order = bulkOrders[bulkOrderId];
        if (order.state != BulkOrderState.OPEN) {
            revert InvalidBulkOrderStateTransition();
        }
        
        stableToken.transfer(_msgSender(), order.stableTokenReceived);
        order.state = BulkOrderState.CLOSED;
        emit BulkOrderClosed(bulkOrderId);

        _createNewBulkOrder();
    }

    /**
     * Mint Num ETF Tokens to fill Mint orders. This calls the Num ETF Token contract and actually mints the requested amount.
     * @dev This can only be called by Managers, and should only be called *after* the underlying assets are actually obtained.
     */
    function mintForBulkOrder(uint256 bulkOrderId, uint256 etfTokensObtained) public onlyRole(MANAGER_ROLE) {
        BulkOrder storage order = bulkOrders[bulkOrderId];
        if (order.state != BulkOrderState.CLOSED) {
            revert InvalidBulkOrderStateTransition();
        }
        order.etfTokenAmountMinted = etfTokensObtained;
        etfToken.mint(_msgSender(), etfTokensObtained);

        order.state = BulkOrderState.MINTED;
        emit BulkOrderMinted(bulkOrderId, etfTokensObtained);
    }

    /**
     * Mark a Bulk Order as Fulfilled.
     * @dev This does not have any effect other than book-keeping.
     * @dev Should only be called *after* tokens resulting from the bulk order have been successfully distributed.
     */
    function markBulkOrderFulfilled(uint256 bulkOrderId) public onlyRole(MANAGER_ROLE) {
        BulkOrder storage order = bulkOrders[bulkOrderId]; 
        if (order.state != BulkOrderState.MINTED) {
            revert InvalidBulkOrderStateTransition();
        }

        emit BulkOrderFulfilled(bulkOrderId);
        order.state = BulkOrderState.FULFILLED;
    }
}
