pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/ERC20.sol";
import "openzeppelin/access/AccessControl.sol";
import "openzeppelin/metatx/ERC2771Context.sol";

contract NumToken is ERC20, AccessControl, ERC2771Context {
    /* Metadata modification role */
    bytes32 public constant METADATA_ROLE = keccak256("METADATA_ROLE");
    string private _name;
    string private _symbol;

    function name() public override view returns (string memory) {
        return _name;
    }

    function symbol() public override view returns (string memory) {
        return _symbol;
    }

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

    /* Transfer taxes */
    bytes32 public constant TAX_ROLE = keccak256("TAX_ROLE");
    address public taxCollector = address(0);
    uint16 public taxBasisPoints = 0;
    event TaxCollectorChanged(address indexed newCollector);
    event TaxChanged(uint256 indexed basisPoints);

    /* Circuit breaker */
    bytes32 public constant CIRCUIT_BREAKER_ROLE = keccak256("CIRCUIT_BREAKER_ROLE");
    bool public paused = false;
    event PauseStateChanged(bool indexed paused);

    constructor(string memory name_, string memory symbol_, address forwarder_) ERC20(name_, symbol_) ERC2771Context(forwarder_) {
        _name = name_;
        _symbol = symbol_;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /* Metadata */
    function setName(string memory name_) public onlyRole(METADATA_ROLE) {
        _name = name_;
    }

    function setSymbol(string memory symbol_) public onlyRole(METADATA_ROLE) {
        _symbol = symbol_;
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

        // transfer tax is calculated based on amount sent.
        // `recipient` should receive amount * (10000 - taxBasisPoints) / 10000
        // transfer tax should not be collected if `taxCollector` is not set
        uint256 tax = taxBasisPoints == 0 || taxCollector == address(0)?
                      0 : amount * taxBasisPoints / 10_000;

        super._transfer(sender, recipient, amount - tax);
        
        if (tax > 0) {
            super._transfer(sender, taxCollector, tax);
        }
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

    /* Tax configuration management */

    function setTaxBasisPoints(uint16 bp) public onlyRole(TAX_ROLE) {
        taxBasisPoints = bp;
        emit TaxChanged(taxBasisPoints);
    }

    function setTaxCollector(address _taxCollector) public onlyRole(TAX_ROLE) {
        taxCollector = _taxCollector;
        emit TaxCollectorChanged(taxCollector);
    }

    function togglePause() public onlyRole(CIRCUIT_BREAKER_ROLE) {
        paused = !paused;
        emit PauseStateChanged(paused);
    }
}

