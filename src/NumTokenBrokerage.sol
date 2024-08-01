/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import "./NumToken.sol";
import {IERC20Metadata as IERC20} from "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
import "openzeppelin/access/AccessControl.sol";
import "forge-std/console.sol";

interface IDssTokenBrokerage {
    function sellGem(address usr, uint256 gemAmt) external;
    function buyGem(address usr, uint256 daiAmt) external;
    function rely(address usr) external;
    function deny(address usr) external;

    function tin() external view returns (uint256);
    function tout() external view returns (uint256);
}

interface IFunctionsConsumer {
    function s_lastResponse() external view returns (bytes memory);
}

/**
 * @dev This contract is a reimplementation/repurposing of MakerDAO's DssPsm
 *      interface for Num's simpler Num Stable Token system.
 * @author Felipe Buiras
 */
contract NumTokenBrokerage is AccessControl, IDssTokenBrokerage {
    uint256 public constant ONE = 10 ** 18;
    bytes32 public constant BROKERAGE_ADMIN_ROLE =
        keccak256("BROKERAGE_ADMIN_ROLE");
    uint256 public immutable to18ConversionFactor;

    NumToken public immutable token;
    IFunctionsConsumer public immutable oracle;
    IERC20 public immutable counterpart;

    uint256 public tin = 0;
    uint256 public tout = 0;
    uint256 public line = 0;
    uint256 public debt = 0;
    bool public stop = false;

    constructor(
        NumToken _token,
        IERC20 _counterpart,
        IFunctionsConsumer _oracle
    ) AccessControl() {
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
     * @param usr address -- address to be added to the admin group
     */
    function rely(
        address usr
    ) external override onlyRole(BROKERAGE_ADMIN_ROLE) {
        _grantRole(BROKERAGE_ADMIN_ROLE, usr);
    }

    /**
     * @notice Remove an address from the authorized list that may change
     *         contract parameters
     * @param usr address -- address to be removed from the admin group
     */
    function deny(
        address usr
    ) external override onlyRole(BROKERAGE_ADMIN_ROLE) {
        _revokeRole(BROKERAGE_ADMIN_ROLE, usr);
    }

    /**
     * @notice Change contract parameters
     * @param what bytes32 -- The key to change
     * @param data uint256 -- The value to set
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
     * @notice Get the current price reported by the Chainlink oracle
     * @dev the Chainlink Functions contract returns the price of the nStable expressed in USD.
     */
    function price() public view returns (uint256) {
        return uint256(bytes32(oracle.s_lastResponse()));
    }

    /**
     * @notice Preview a sellGem operation, returning the nStable amount
     *         that would be acquired.
     * @param gemAmt uint256 -- Amount of the counterpart token that would be
     *         sold
     * @return uint256 -- Amout of nStables that would be acquired
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
     * @param numAmount uint256 -- Amount of the nStable token that would be
     *         sold
     * @return uint256 -- Amout of counterpart tokens that would be acquired
     */
    function previewBuyGem(uint256 numAmount) public view returns (uint256) {
        require(tout < ONE, "NumTokenBrokerage: tout must be less than ONE");
        return (
            numAmount * price() / ONE / to18ConversionFactor * (ONE - tout) / ONE
        );
    }

    /**
     * @notice Sell counterpart tokens for Num Tokens
     * @param usr address -- the address that will receive the tokens
     * @params gemAmt uint256 -- the amount of counterpart tokens to sell
     */
    function sellGem(address usr, uint256 gemAmt) external override notStopped {
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
     * @param usr address -- the address that will receive the tokens
     * @params numAmount uint256 -- the amount of nStable tokens to sell
     */
    function buyGem(
        address usr,
        uint256 numAmount
    ) external override notStopped {
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
     * @param to address -- address that will receive the tokens
     * @param amount uint256 -- amount of counterpart tokens to withdraw
     */
    function take(
        address to,
        uint256 amount
    ) external onlyRole(BROKERAGE_ADMIN_ROLE) {
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
     * @param amount uint256 -- amount of counterpart tokens to deposit
     * @dev this function is left external since we don't care about unauthorized
     *      addresses sending counterpart tokens to this contract
     */
    function give(uint256 amount) external {
        require(
            counterpart.transferFrom(msg.sender, address(this), amount),
            "NumTokenBrokerage: Transfer failed"
        );
    }
}
