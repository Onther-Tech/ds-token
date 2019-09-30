/// token.sol -- ERC20 implementation with minting and burning

// Copyright (C) 2015, 2016, 2017  DappHub, LLC

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.4.24;

import "ds-stop/stop.sol";
import "ds-token/token.sol";
import "./RequestableI.sol";


/**
 * @notice RequestableToken implements requestable token inheriting DSToken.
 *         Storage layout is as follows (requestable state is annotated with *)
 *         [0]: DSAuth.authority
 *         [1]: * DSAuth.onwer
 *         [2]: * DSStop.stopped
 *         [3]: DSTokenBase._supply
 *         [4]: * DSTokenBase._balances
 *         [5]: DSTokenBase._approvals
 *         [6]: DSToken.symbol
 *         [7]: DSToken.decimals
 *         [8]: DSToken.name
 *         [9]: RequestableToken.rootchain
 *         [10]: RequestableToken.appliedRequests
 */
contract RequestableToken is DSToken, RequestableI {

    address public rootchain;
    bool public development;

    /* Events */
    event Request(bool _isExit, address indexed _requestor, bytes32 _trieKey, uint _value);

    constructor (bool _development, bytes32 symbol_, address rootchain_) DSToken(symbol_) public {
        development = _development;
        rootchain = rootchain_;
    }

    function getBalanceTrieKey(address who) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(bytes32(who), bytes32(4)));
    }

    function applyRequestInRootChain(
        bool isExit,
        uint256 requestId,
        address requestor,
        bytes32 trieKey,
        bytes trieValue
    ) external returns (bool success) {
        require(msg.sender == address(rootchain));
        // require(trieKey == getBalanceTrieKey(requestor));

        uint v = decodeTrieValue(trieValue);

        if (trieKey == bytes32(1)) {
            _handleOwner(true, isExit, requestor, trieKey, v);
        } else if (trieKey == bytes32(2)) {
            _handleStopped(true, isExit, requestor, trieKey, v);
        } else if (trieKey == getBalanceTrieKey(requestor)) {
            _handleBalance(true, isExit, requestor, trieKey, v);
        } else {
            revert();
        }

        emit Request(isExit, requestor, trieKey, v);

        return true;
    }

    function applyRequestInChildChain(
        bool isExit,
        uint256 requestId,
        address requestor,
        bytes32 trieKey,
        bytes trieValue
    ) external returns (bool success) {
        require(development || msg.sender == address(0));
        // require(trieKey == getBalanceTrieKey(requestor));

        uint v = decodeTrieValue(trieValue);

        if (trieKey == bytes32(1)) {
            _handleOwner(false, isExit, requestor, trieKey, v);
        } else if (trieKey == bytes32(2)) {
            _handleStopped(false, isExit, requestor, trieKey, v);
        } else if (trieKey == getBalanceTrieKey(requestor)) {
            _handleBalance(false, isExit, requestor, trieKey, v);
        } else {
            revert();
        }

        emit Request(isExit, requestor, trieKey, v);

        return true;
    }

    function decodeTrieValue(bytes memory trieValue) public pure returns (uint v) {
        require(trieValue.length == 0x20);

        assembly {
            v := mload(add(trieValue, 0x20))
        }
    }

    function _handleOwner(
        bool isRootChain,
        bool isExit,
        address requestor,
        bytes32 trieKey,
        uint v
    ) internal {
        address newOwner = address(v);

        if (isRootChain) {
            if (isExit) {
                owner = newOwner;
            } else {
                require(owner == requestor);
                require(owner == newOwner);
            }
        } else {
            if (isExit) {
                require(owner == requestor);
                require(owner == newOwner);
            } else {
                owner = newOwner;
            }
        }
    }

    function _handleStopped(
        bool isRootChain,
        bool isExit,
        address requestor,
        bytes32 trieKey,
        uint v
    ) internal {
        bool newStopped = v == 0x1;

        if (isRootChain) {
            if (isExit) {
                stopped = newStopped;
            } else {
                require(isAuthorized(requestor, bytes4(keccak256("stop()"))));
            }
        } else {
            if (isExit) {
                require(isAuthorized(requestor, bytes4(keccak256("stop()"))));
            } else {
                stopped = newStopped;
            }
        }
    }

    function _handleBalance(
        bool isRootChain,
        bool isExit,
        address requestor,
        bytes32 trieKey,
        uint amount
    ) internal {
        /* uint amount = uint(trieValue); */

        if (isRootChain) {
            if (isExit) {
                _balances[requestor] = add(_balances[requestor], amount);
            } else {
                require(amount <= _balances[requestor]);
                _balances[requestor] = sub(_balances[requestor], amount);
            }
        } else {
            if (isExit) {
                require(amount <= _balances[requestor]);
                _balances[requestor] = sub(_balances[requestor], amount);
            } else {
                _balances[requestor] = add(_balances[requestor], amount);
            }
        }
    }
}
