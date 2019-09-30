/// token.t.sol -- test for token.sol

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

import "ds-test/test.sol";

import "./RequestableToken.sol";

contract TokenUser {
    RequestableToken token;

    constructor(RequestableToken token_) public {
        token = token_;
    }
}

contract OwnerUser {
    function setOwner(DSAuth auth_, address newOwner_) public {
        auth_.setOwner(newOwner_);
    }
}

contract RequestableTokenTest is DSTest {
    uint constant initialBalance = 1000;

    RequestableToken token;

    OwnerUser ownerUser;
    TokenUser tokenUser1;
    TokenUser tokenUser2;

    function setUp() public {
        token = createToken();
        token.mint(initialBalance);
        ownerUser = new OwnerUser();
        tokenUser1 = new TokenUser(token);
        tokenUser2 = new TokenUser(token);
    }

    function createToken() internal returns (RequestableToken) {
        return new RequestableToken(true, 'TST', this);
    }

    function toBytesUint(uint256 x) public returns (bytes b) {
        b = new bytes(32);
        assembly { mstore(add(b, 32), x) }
    }

    function toBytesAddress(address x) public returns (bytes b) {
        b = new bytes(32);
        assembly { mstore(add(b, 32), x) }
    }

    function testApplyOwner() public {
        bool isExit = true;
        uint requestId = 0;
        bytes32 trieKey = 0x1;
        bytes memory trieValue;

        // initial
        assertEq(token.owner(), this);

        // exit in root chain
        trieValue = toBytesAddress(ownerUser);
        token.applyRequestInRootChain(isExit, requestId, this, trieKey, trieValue);
        assertEq(token.owner(), address(ownerUser));

        // reset owner
        ownerUser.setOwner(token, this);
        assertEq(token.owner(), this);

        // enter in root chain
        isExit = false;
        requestId += 1;
        trieValue = toBytesAddress(this);
        token.applyRequestInRootChain(isExit, requestId, this, trieKey, trieValue);
        assertEq(token.owner(), this);

        // exit in child chain
        isExit = true;
        requestId += 1;
        trieValue = toBytesAddress(this);
        token.applyRequestInChildChain(isExit, requestId, this, trieKey, trieValue);
        assertEq(token.owner(), this);

        // enter in child chain
        isExit = false;
        requestId += 1;
        trieValue = toBytesAddress(ownerUser);
        token.applyRequestInChildChain(isExit, requestId, this, trieKey, trieValue);
        assertEq(token.owner(), address(ownerUser));

        // reset owner
        ownerUser.setOwner(token, this);
        assertEq(token.owner(), this);
    }

    function testApplyStopped() public {
        bool stopped = true;
        bool notStopped = false;

        bool isExit = true;
        uint requestId = 0;
        bytes32 trieKey = 0x2;
        bytes memory trieValue;

        // initial
        assertTrue(token.stopped() == notStopped);

        // exit in root chain
        trieValue = toBytesUint(0x1);
        token.applyRequestInRootChain(isExit, requestId, this, trieKey, trieValue);
        assertTrue(token.stopped() == stopped);

        // enter in root chain
        isExit = false;
        requestId += 1;
        trieValue = toBytesUint(0x1);
        token.applyRequestInRootChain(isExit, requestId, this, trieKey, trieValue);
        assertTrue(token.stopped() == stopped);

        // exit in child chain
        isExit = true;
        requestId += 1;
        trieValue = toBytesUint(0x1);
        token.applyRequestInChildChain(isExit, requestId, this, trieKey, trieValue);
        assertTrue(token.stopped() == stopped);

        // enter in child chain
        isExit = false;
        requestId += 1;
        trieValue = toBytesUint(0x0);
        token.applyRequestInChildChain(isExit, requestId, this, trieKey, trieValue);
        assertTrue(token.stopped() == notStopped);
    }


    function testApplyBalance() public {
        bool isExit;
        uint requestId;
        address requestor = address(tokenUser1);
        bytes32 trieKey = token.getBalanceTrieKey(tokenUser1);
        bytes memory trieValue;

        // initial
        token.push(tokenUser1, 100);
        assertEq(token.balanceOf(tokenUser1), 100);

        // enter in root chain
        isExit = false;
        requestId += 1;
        trieValue = toBytesUint(10);
        token.applyRequestInRootChain(isExit, requestId, requestor, trieKey, trieValue);
        assertEq(token.balanceOf(tokenUser1), 90);

        // exit in root chain
        isExit = true;
        requestId += 1;
        trieValue = toBytesUint(10);
        token.applyRequestInRootChain(isExit, requestId, requestor, trieKey, trieValue);
        assertEq(token.balanceOf(tokenUser1), 100);

        // exit in child chain
        isExit = true;
        requestId += 1;
        trieValue = toBytesUint(10);
        token.applyRequestInChildChain(isExit, requestId, requestor, trieKey, trieValue);
        assertEq(token.balanceOf(tokenUser1), 90);

        // enter in child chain
        isExit = false;
        requestId += 1;
        trieValue = toBytesUint(10);
        token.applyRequestInChildChain(isExit, requestId, requestor, trieKey, trieValue);
        assertEq(token.balanceOf(tokenUser1), 100);
    }
}
