/// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.22;

import "./NumToken.sol";
import "./PriceProvider.sol";
import "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";
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
    using SafeERC20 for NumToken;
    using SafeERC20 for IERC20Metadata;

    uint256 public constant ONE = 10 ** 18;
    bytes32 public constant BROKERAGE_ADMIN_ROLE =
        keccak256("BROKERAGE_ADMIN_ROLE");
    uint256 public immutable to18ConversionFactor;

    /// @notice nStable token managed by this brokerage contract
    NumToken public immutable token;

    /// @notice counterpart token for this contract
    IERC20Metadata public immutable counterpart;

    /// @notice Price provider contract
    PriceProvider public oracle;

    /// @notice sellGem tax. Defined as (1 ether) = 100%
    uint256 _tin = 0;
    uint256 timelockedTin = 0;
    uint256 timelockedTinApplies = type(uint256).max;

    /// @notice buyGem tax. Defined as (1 ether) = 100%
    uint256 _tout = 0;
    uint256 timelockedTout = 0;
    uint256 timelockedToutApplies = type(uint256).max;

    /// @notice the debt ceiling of this contract - cannot emit more than this figure
    uint256 public line = 0;

    /// @notice the current utilization of the debt ceiling
    uint256 public debt = 0;

    /// @notice whether this contract is operational at this time
    bool public stop = false;

    /// @notice how much time a tin/tout file needs to wait before it is applied
    uint256 timelock = 0;

    error InvalidFileKey();
    error InvalidFileData();

    event FileChangeStaged(bytes32 indexed what, uint256 value);
    event FileChanged(bytes32 indexed what, uint256 value);

    constructor(
        NumToken _token,
        IERC20Metadata _counterpart,
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
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(BROKERAGE_ADMIN_ROLE, usr);
    }

    /**
     * @notice Remove an address from the authorized list that may change
     *         contract parameters
     * @param usr address to be removed from the admin group
     */
    function deny(
        address usr
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
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
    ) external checkTimelocks onlyRole(BROKERAGE_ADMIN_ROLE) {
        if (what == "tin") {
            if (data >= ONE) {
                revert InvalidFileData();
            }
            timelockedTin = data;
            timelockedTinApplies = block.timestamp + timelock;
            emit FileChangeStaged(what, data);
        } else if (what == "tout") {
            if (data >= ONE) {
                revert InvalidFileData();
            }
            timelockedTout = data;
            timelockedToutApplies = block.timestamp + timelock;
            emit FileChangeStaged(what, data);
        } else if (what == "line") {
            emit FileChanged(what, data);
            line = data;
        } else if (what == "stop") {
            stop = data != 0;
            emit FileChanged(what, data);
        } else if (what == "lock") {
            timelock = data;
            emit FileChanged(what, data);
        } else {
            revert InvalidFileKey();
        }
    }

    /**
     * @notice Get the current price reported by the PriceProvider contracxt
     * @dev the contract returns the price of the nStable expressed in USD.
     */
    function price() public view returns (uint256) {
        return oracle.getPrice();
    }

    function tin() public view returns (uint256) {
        if (timelockedTinApplies < block.timestamp) {
            return timelockedTin;
        } else {
            return _tin;
        }
    }

    function tout() public view returns (uint256) {
        if (timelockedToutApplies < block.timestamp) {
            return timelockedTout;
        } else {
            return _tout;
        }
    }

    /**
     * @notice Check the timelocks before doing calculations and update values
     *         if necessary.
     */
    modifier checkTimelocks() {
        if (timelockedTinApplies > block.timestamp) {
            _tin = timelockedTin;
            timelockedTinApplies = type(uint256).max;
            emit FileChanged("tin", _tin);
        }
        if (timelockedToutApplies > block.timestamp) {
            _tout = timelockedTout;
            timelockedToutApplies = type(uint256).max;
            emit FileChanged("tout", _tout);
        }
        _;
    }

    /**
     * @notice Preview a sellGem operation, returning the nStable amount
     *         that would be acquired.
     * @param gemAmt Amount of the counterpart token that would be
     *         sold
     * @return Amount of nStables that would be acquired
     */
    function previewSellGem(uint256 gemAmt) public view returns (uint256) {
        return (
            (gemAmt * to18ConversionFactor) * ONE / price() * (ONE - tin()) / ONE
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
        return (
            numAmount * price() / ONE / to18ConversionFactor * (ONE - tout()) / ONE
        );
    }

    /**
     * @notice Sell counterpart tokens for Num Tokens
     * @param usr the address that will receive the tokens
     * @param gemAmt the amount of counterpart tokens to sell
     */
    function sellGem(address usr, uint256 gemAmt) external override checkTimelocks nonReentrant notStopped {
        require(usr == msg.sender, "NumTokenBrokerage: Unauthorized");
        counterpart.safeTransferFrom(usr, address(this), gemAmt);
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
    ) external override checkTimelocks nonReentrant notStopped {
        require(usr == msg.sender, "NumTokenBrokerage: Unauthorized");
        token.burn(usr, numAmount);
        uint256 gemAmount = previewBuyGem(numAmount);
        debt -= numAmount;
        counterpart.safeTransfer(usr, gemAmount);
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
        counterpart.safeTransfer(to, amount);
    }

    /**
     * @notice Return counterpart tokens to the brokerage contract
     * @param amount amount of counterpart tokens to deposit
     * @dev this function is left external since we don't care about unauthorized
     *      addresses sending counterpart tokens to this contract
     */
    function give(uint256 amount) nonReentrant external {
        counterpart.safeTransferFrom(msg.sender, address(this), amount);
    }
}
