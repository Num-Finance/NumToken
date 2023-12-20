// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./NumToken.sol";
import "layerzero/token/oft/v2/OFTCoreV2.sol";


contract LZNumToken is NumToken, OFTCoreV2 {
    uint internal ld2sdRate;

    constructor(address _forwarder, address _endpoint) NumToken(_forwarder) OFTCoreV2(6, _endpoint) {}

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
}