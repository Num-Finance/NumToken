/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import "./NumToken.sol";
import "./PriceProvider.sol";
import {IERC20Metadata as IERC20} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import "openzeppelin/access/AccessControl.sol";
import "openzeppelin/security/ReentrancyGuard.sol";

interface IDssTokenBrokerage {
    function sellGem(address usr, uint256 gemAmt) external;
    function buyGem(address usr, uint256 daiAmt) external;
    function rely(address usr) external;
    function deny(address usr) external;

    function tin() external view returns (uint256);
    function tout() external view returns (uint256);
}

/**
 * @dev This contract is a reimplementation/repurposing of MakerDAO's DssPsm
 *      interface for Num's simpler Num Stable Token system.
 * @author Felipe Buiras
 */
contract NumTokenBrokerage is ReentrancyGuard, AccessControl, IDssTokenBrokerage {
    uint256 public constant ONE = 10 ** 18;
    bytes32 public constant BROKERAGE_ADMIN_ROLE =
        keccak256("BROKERAGE_ADMIN_ROLE");
    uint256 public immutable to18ConversionFactor;

    /// @notice nStable token managed by this brokerage contract
    NumToken public immutable token;

    /// @notice counterpart token for this contract
    IERC20 public immutable counterpart;

    /// @notice Price provider contract
    PriceProvider public oracle;

    /// @notice sellGem tax. Defined as (1 ether) = 100%
    uint256 public tin = 0;

    /// @notice buyGem tax. Defined as (1 ether) = 100%
    uint256 public tout = 0;

    /// @notice the debt ceiling of this contract - cannot emit more than this figure
    uint256 public line = 0;

    /// @notice the current utilization of the debt ceiling
    uint256 public debt = 0;

    /// @notice whether this contract is operational at this time
    bool public stop = false;

    constructor(
        NumToken _token,
        IERC20 _counterpart,
        PriceProvider _oracle
    ) AccessControl() ReentrancyGuard() {
        token = _token;
        counterpart = _counterpart;
        oracle = _oracle;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(BROKERAGE_ADMIN_ROLE, msg.sender);
        to18ConversionFactor = 10 ** (18 - counterpart.decimals());
    }

    modifier notStopped() {
        require(!stop, "NumTokenBrokerage: Brokerage is stopped");
        _;
    }

    /**
     * @notice Add an address to the authorized list that may change
     *         contract parameters
     * @param usr address to be added to the admin group
     */
    function rely(
        address usr
    ) external override onlyRole(BROKERAGE_ADMIN_ROLE) {
        _grantRole(BROKERAGE_ADMIN_ROLE, usr);
    }

    /**
     * @notice Remove an address from the authorized list that may change
     *         contract parameters
     * @param usr address to be removed from the admin group
     */
    function deny(
        address usr
    ) external override onlyRole(BROKERAGE_ADMIN_ROLE) {
        _revokeRole(BROKERAGE_ADMIN_ROLE, usr);
    }

    /**
     * @notice Change contract parameters
     * @param what The key to change
     * @param data The value to set
     */
    function file(
        bytes32 what,
        uint256 data
    ) external onlyRole(BROKERAGE_ADMIN_ROLE) {
        if (what == "tin") {
            require(data <= ONE, "NumTokenBrokerage: Invalid value");
            tin = data;
        } else if (what == "tout") {
            require(data <= ONE, "NumTokenBrokerage: Invalid value");
            tout = data;
        } else if (what == "line") {
            line = data;
        } else if (what == "stop") {
            stop = data != 0;
        } else {
            revert("NumTokenBrokerage: Invalid file");
        }
    }

    /**
     * @notice Get the current price reported by the PriceProvider contracxt
     * @dev the contract returns the price of the nStable expressed in USD.
     */
    function price() public view returns (uint256) {
        return oracle.getPrice();
    }

    /**
     * @notice Preview a sellGem operation, returning the nStable amount
     *         that would be acquired.
     * @param gemAmt Amount of the counterpart token that would be
     *         sold
     * @return Amount of nStables that would be acquired
     */
    function previewSellGem(uint256 gemAmt) public view returns (uint256) {
        require(tin < ONE, "NumTokenBrokerage: tin must be less than ONE");
        return (
            (gemAmt * to18ConversionFactor) * ONE / price() * (ONE - tin) / ONE
        );
    }

    /**
     * @notice Preview a buyGem operation, returning the amount
     *         of counterpart tokens that would be acquired.
     * @param numAmount Amount of the nStable token that would be
     *         sold
     * @return Amount of counterpart tokens that would be acquired
     */
    function previewBuyGem(uint256 numAmount) public view returns (uint256) {
        require(tout < ONE, "NumTokenBrokerage: tout must be less than ONE");
        return (
            numAmount * price() / ONE / to18ConversionFactor * (ONE - tout) / ONE
        );
    }

    /**
     * @notice Sell counterpart tokens for Num Tokens
     * @param usr the address that will receive the tokens
     * @param gemAmt the amount of counterpart tokens to sell
     */
    function sellGem(address usr, uint256 gemAmt) external override nonReentrant notStopped {
        require(usr == msg.sender, "NumTokenBrokerage: Unauthorized");
        require(
            counterpart.transferFrom(usr, address(this), gemAmt),
            "NumTokenBrokerage: Transfer failed"
        );
        uint256 numAmount = previewSellGem(gemAmt);
        debt += numAmount;
        require(debt <= line, "NumTokenBrokerage: Debt ceiling reached");
        token.mint(usr, numAmount);
    }

    /**
     * @notice Buy counterpart tokens with Num Tokens
     * @param usr the address that will receive the tokens
     * @param numAmount the amount of nStable tokens to sell
     */
    function buyGem(
        address usr,
        uint256 numAmount
    ) external override nonReentrant notStopped {
        require(usr == msg.sender, "NumTokenBrokerage: Unauthorized");
        token.burn(usr, numAmount);
        uint256 gemAmount = previewBuyGem(numAmount);
        debt -= numAmount;
        require(
            counterpart.transfer(usr, gemAmount),
            "NumTokenBrokerage: Transfer failed"
        );
    }

    /**
     * @notice Take counterpart tokens out of the brokerage contract
     * @dev this function can only be called by administrators
     * @param to address that will receive the tokens
     * @param amount amount of counterpart tokens to withdraw
     */
    function take(
        address to,
        uint256 amount
    ) external nonReentrant onlyRole(BROKERAGE_ADMIN_ROLE) {
        require(
            amount <= counterpart.balanceOf(address(this)),
            "NumTokenBrokerage: Insufficient balance"
        );
        require(
            counterpart.transfer(to, amount),
            "NumTokenBrokerage: Transfer failed"
        );
    }

    /**
     * @notice Return counterpart tokens to the brokerage contract
     * @param amount amount of counterpart tokens to deposit
     * @dev this function is left external since we don't care about unauthorized
     *      addresses sending counterpart tokens to this contract
     */
    function give(uint256 amount) nonReentrant external {
        require(
            counterpart.transferFrom(msg.sender, address(this), amount),
            "NumTokenBrokerage: Transfer failed"
        );
    }
}
