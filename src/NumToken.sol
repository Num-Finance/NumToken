pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/AccessControl.sol";
import "openzeppelin/metatx/ERC2771Context.sol";

contract NumToken is ERC20, AccessControl, ERC2771Context {
    function _msgSender() internal view virtual override(Context, ERC2771Context) returns (address) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view virtual override(Context, ERC2771Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    bytes32 public constant MINTER_BURNER_ROLE = keccak256("MINTER_BURNER_ROLE");

    /* Disallow list control */
    bytes32 public constant DISALLOW_ROLE = keccak256("DISALLOW_ROLE");
    mapping(address => bool) private _disallowed;
    event Disallowed(address indexed account);
    event Allowed(address indexed account);

    /* Circuit breaker */
    bytes32 public constant CIRCUIT_BREAKER_ROLE = keccak256("CIRCUIT_BREAKER_ROLE");
    bool public paused = false;
    event PauseStateChanged(bool indexed paused);

    constructor(string memory name_, string memory symbol_, address forwarder_) ERC20(name_, symbol_) ERC2771Context(forwarder_) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /* Mint/Burn */

    function mint(address account, uint256 amount) public onlyRole(MINTER_BURNER_ROLE) {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public onlyRole(MINTER_BURNER_ROLE) {
        _burn(account, amount);
    }

    /**
     * ERC20 _transfer override
     */
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        /**
          Disallow transfers whenever the circuit breaker is pulled.
          This check is done here since we have to allow mint() and burn()
          calls while in this state, to enable clawback of funds if they are stolen.
        */
        require(!paused, "NumToken: transfers paused");

        super._transfer(sender, recipient, amount);
    }

    /* Disallow list management */
    function disallow(address account) public onlyRole(DISALLOW_ROLE) {
        _disallowed[account] = true;
        emit Disallowed(account);
    }

    function allow(address account) public onlyRole(DISALLOW_ROLE) {
        _disallowed[account] = false;
        emit Allowed(account);
    }

    function isDisallowed(address account) public view returns (bool) {
        return _disallowed[account];
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
        /* Disallow transfers to and from disallowed accounts */
        require(!_disallowed[from] && ! _disallowed[to], "NumToken: Disallowed account");
    }

    function togglePause() public onlyRole(CIRCUIT_BREAKER_ROLE) {
        paused = !paused;
        emit PauseStateChanged(paused);
    }
}

