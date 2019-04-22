pragma solidity ^0.4.24;

import "ds-test/test.sol";

import "./RequestableWrapperToken.sol";
import "ds-token/token.sol";

contract RootChain {
  RequestableWrapperToken wrapperToken;
  constructor(RequestableWrapperToken wrapperToken_) public {
      wrapperToken = wrapperToken_;
  }
  function doApplyInRootChain(
    bool isExit,
    uint256 requestId,
    address requestor,
    bytes32 trieKey,
    bytes trieValue) public {
    wrapperToken.applyRequestInRootChain(isExit, requestId, requestor, trieKey, trieValue);
  }
}

contract RequestableWrapperTokenTest is DSTest {
    RequestableWrapperToken wrapperToken;
    DSToken token;
    RootChain rootchain;
    address NullAddress = address(0);

    function setUp() public {
        token = new DSToken('TEST');
        wrapperToken = new RequestableWrapperToken(true, 'WRAPPER', token);
        rootchain = new RootChain(wrapperToken);
        wrapperToken.init(address(rootchain));
        assertTrue(wrapperToken.initialized());
    }

    function doApplyInChildChain(
      bool isExit,
      uint256 requestId,
      address requestor,
      bytes32 trieKey,
      bytes trieValue) public {
      wrapperToken.applyRequestInChildChain(isExit, requestId, requestor, trieKey, trieValue);
    }

    function toBytes(uint256 x) returns (bytes b) {
        b = new bytes(32);
        assembly { mstore(add(b, 32), x) }
    }

    function testDepositAndWithdraw() public {
      token.mint(100);
      assertEq(token.balanceOf(this), 100);

      token.approve(wrapperToken);
      wrapperToken.deposit(100);
      assertEq(wrapperToken.balanceOf(this), 100);

      wrapperToken.withdraw(100);
      assertEq(wrapperToken.balanceOf(this), 0);
      assertEq(token.balanceOf(this), 100);
    }

    function testApply() public {
      // init
      token.mint(100);
      token.approve(wrapperToken);
      wrapperToken.deposit(100);

      // enter in root chain
      bool isExit = false;
      uint requestId = 0;
      bytes32 trieKey = wrapperToken.getBalanceTrieKey(this);
      bytes memory trieValue;

      trieValue = toBytes(10);
      rootchain.doApplyInRootChain(isExit, requestId, this, trieKey, trieValue);
      assertEq(wrapperToken.balanceOf(this), 90);

      // enter in child chain
      trieValue = toBytes(10);
      wrapperToken.applyRequestInChildChain(isExit, requestId, this, trieKey, trieValue);

      assertEq(wrapperToken.balanceOf(this), 100);

      // exit in root chain
      isExit = true;
      trieValue = toBytes(10);
      rootchain.doApplyInRootChain(isExit, requestId, this, trieKey, trieValue);
      assertEq(wrapperToken.balanceOf(this), 110);

      // exit in child chain
      trieValue = toBytes(10);
      wrapperToken.applyRequestInChildChain(isExit, requestId, this, trieKey, trieValue);
      assertEq(wrapperToken.balanceOf(this), 100);
    }
}
