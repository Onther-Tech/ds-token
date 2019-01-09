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

pragma solidity ^0.4.23;

import "ds-stop/stop.sol";
import "./lib/Ownable.sol";
import "./token.sol";

import "./base.sol";

contract RQToken is DSToken, Ownable {

    bytes32  public  symbol;
    uint256  public  decimals = 18; // standard token precision. override to customize

    function RQToken(bytes32 symbol_) DSToken(symbol_) public {
        symbol = symbol_;
    }

    // requests
    mapping(uint => bool) appliedRequests;

    /* Events */
    event Mint(address indexed guy, uint wad);
    event Burn(address indexed guy, uint wad);
    event Request(bool _isExit, address indexed _requestor, bytes32 _trieKey, bytes32 _trieValue);


    function approve(address guy) public stoppable returns (bool) {
        return super.approve(guy, uint(-1));
    }

    function approve(address guy, uint wad) public stoppable returns (bool) {
        return super.approve(guy, wad);
    }

    // User can get the trie key of one's balance and make an enter request directly.
    function getBalanceTrieKey(address who) public pure returns (bytes32) {
        return keccak256(bytes32(who), bytes32(2));
    }

    function applyRequestInRootChain(
        bool isExit,
        uint256 requestId,
        address requestor,
        bytes32 trieKey,
        bytes32 trieValue
    ) public returns (bool success) {
        // TODO: adpot RootChain
        // require(msg.sender == address(rootchain));
        // require(!getRequestApplied(requestId)); // check double applying

        require(!appliedRequests[requestId]);

        if (isExit) {
            // exit must be finalized.
            // TODO: adpot RootChain
            // require(rootchain.getExitFinalized(requestId));

            if(bytes32(0) == trieKey) {
                // only owner (in child chain) can exit `owner` variable.
                // but it is checked in applyRequestInChildChain and exitChallenge.

                // set requestor as owner in root chain.
                owner = requestor;
            } else if(bytes32(1) == trieKey) {
                // no one can exit `totalSupply` variable.
                // but do nothing to return true.
            } else if (keccak256(bytes32(requestor), bytes32(2)) == trieKey) {
                // this checks trie key equals to `balances[requestor]`.
                // only token holder can exit one's token.
                // exiting means moving tokens from child chain to root chain.
                _balances[requestor] += uint(trieValue);
            } else {
                // cannot exit other variables.
                // but do nothing to return true.
            }
        } else {
            // apply enter
            if(bytes32(0) == trieKey) {
                // only owner (in root chain) can enter `owner` variable.
                require(owner == requestor);
                // do nothing in root chain
            } else if(bytes32(1) == trieKey) {
                // no one can enter `totalSupply` variable.
                revert();
            } else if (keccak256(bytes32(requestor), bytes32(2)) == trieKey) {
                // this checks trie key equals to `balances[requestor]`.
                // only token holder can enter one's token.
                // entering means moving tokens from root chain to child chain.
                require(_balances[requestor] >= uint(trieValue));
                _balances[requestor] -= uint(trieValue);
            } else {
                // cannot apply request on other variables.
                revert();
            }
        }

        appliedRequests[requestId] = true;

        emit Request(isExit, requestor, trieKey, trieValue);

        // TODO: adpot RootChain
        // setRequestApplied(requestId);
        return true;
    }

    // this is only called by NULL_ADDRESS in child chain
    // when i) exitRequest is initialized by startExit() or
    //     ii) enterRequest is initialized
    function applyRequestInChildChain(
        bool isExit,
        uint256 requestId,
        address requestor,
        bytes32 trieKey,
        bytes32 trieValue
    ) external returns (bool success) {
        // TODO: adpot child chain
        // require(msg.sender == NULL_ADDRESS);
        require(!appliedRequests[requestId]);

        if (isExit) {
            if(bytes32(0) == trieKey) {
                // only owner (in child chain) can exit `owner` variable.
                require(requestor == owner);

                // do nothing when exit `owner` in child chain
            } else if(bytes32(1) == trieKey) {
                // no one can exit `totalSupply` variable.
                revert();
            } else if (keccak256(bytes32(requestor), bytes32(2)) == trieKey) {
                // this checks trie key equals to `balances[tokenHolder]`.
                // only token holder can exit one's token.
                // exiting means moving tokens from child chain to root chain.

                // revert provides a proof for `exitChallenge`.
                require(_balances[requestor] >= uint(trieValue));

                _balances[requestor] -= uint(trieValue);
            } else { // cannot exit other variables.
                revert();
            }
        } else { // apply enter
            if(bytes32(0) == trieKey) {
                // only owner (in root chain) can make enterRequest of `owner` variable.
                // but it is checked in applyRequestInRootChain.

                owner = requestor;
            } else if(bytes32(1) == trieKey) {
                // no one can enter `totalSupply` variable.
            } else if (keccak256(bytes32(requestor), bytes32(2)) == trieKey) {
                // this checks trie key equals to `balances[tokenHolder]`.
                // only token holder can enter one's token.
                // entering means moving tokens from root chain to child chain.
                _balances[requestor] += uint(trieValue);
            } else {
                // cannot apply request on other variables.
                revert();
            }
        }

        appliedRequests[requestId] = true;

        emit Request(isExit, requestor, trieKey, trieValue);
        return true;
    }


}
