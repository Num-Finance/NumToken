// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.22;

/*import "./NumToken.sol";
import "layerzero/oft/OFTCore.sol";

contract LZNumToken is NumToken, OFTCore {
    uint internal ld2sdRate;

    constructor(address _forwarder, address _endpoint) NumToken(_forwarder) OFTCore(decimals(), _endpoint, _msgSender()) {}

    function _debitFrom(
        address _from,
        uint16 _dstChainId,
        bytes32 _toAddress,
        uint _amount
    ) internal virtual override returns (uint) {
        if (_from != _msgSender()) {
            _spendAllowance(_from, spender, amount);
        }
        _burn(_from, _amount);
        return _amount;
    }

    function _creditTo(
        uint16 _srcChainId,
        address _toAddress,
        uint _amount
    ) internal virtual override returns (uint) {
        _mint(_toAddress, _amount);
    }
    
    function _ld2sdRate() internal view virtual returns (uint) {
        return ld2sdRate;
    }

    function token() external virtual view returns (address) {
        return address(this);
    }

    funciton oftVersion() external pure returns (uint64 major, uint64 minor) {
        major = 1;
        minor = 1;
    }
}*/