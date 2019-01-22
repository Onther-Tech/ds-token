pragma solidity ^0.4.24;

contract DSNote {
    event LogNote(
        bytes4   indexed  sig,
        address  indexed  guy,
        bytes32  indexed  foo,
        bytes32  indexed  bar,
        uint256           wad,
        bytes             fax
    ) anonymous;

    modifier note {
        bytes32 foo;
        bytes32 bar;
        uint256 wad;

        assembly {
            foo := calldataload(4)
            bar := calldataload(36)
            wad := callvalue
        }

        emit LogNote(msg.sig, msg.sender, foo, bar, wad, msg.data);

        _;
    }
}

contract DSAuthority {
    function canCall(
        address src, address dst, bytes4 sig
    ) public view returns (bool);
}

contract DSAuthEvents {
    event LogSetAuthority (address indexed authority);
    event LogSetOwner     (address indexed owner);
}

contract DSAuth is DSAuthEvents {
    DSAuthority  public  authority;
    address      public  owner;

    constructor() public {
        owner = msg.sender;
        emit LogSetOwner(msg.sender);
    }

    function setOwner(address owner_)
        public
        auth
    {
        owner = owner_;
        emit LogSetOwner(owner);
    }

    function setAuthority(DSAuthority authority_)
        public
        auth
    {
        authority = authority_;
        emit LogSetAuthority(address(authority));
    }

    modifier auth {
        require(isAuthorized(msg.sender, msg.sig), "ds-auth-unauthorized");
        _;
    }

    function isAuthorized(address src, bytes4 sig) internal view returns (bool) {
        if (src == address(this)) {
            return true;
        } else if (src == owner) {
            return true;
        } else if (authority == DSAuthority(0)) {
            return false;
        } else {
            return authority.canCall(src, address(this), sig);
        }
    }
}


contract DSStop is DSNote, DSAuth {
    bool public stopped;

    modifier stoppable {
        require(!stopped, "ds-stop-is-stopped");
        _;
    }
    function stop() public auth note {
        stopped = true;
    }
    function start() public auth note {
        stopped = false;
    }

}

contract DSMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "ds-math-add-overflow");
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "ds-math-sub-underflow");
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "ds-math-mul-overflow");
    }

    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }
    function max(uint x, uint y) internal pure returns (uint z) {
        return x >= y ? x : y;
    }
    function imin(int x, int y) internal pure returns (int z) {
        return x <= y ? x : y;
    }
    function imax(int x, int y) internal pure returns (int z) {
        return x >= y ? x : y;
    }

    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;

    function wmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), WAD / 2) / WAD;
    }
    function rmul(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, y), RAY / 2) / RAY;
    }
    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }
    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, RAY), y / 2) / y;
    }

    // This famous algorithm is called "exponentiation by squaring"
    // and calculates x^n with x as fixed-point and n as regular unsigned.
    //
    // It's O(log n), instead of O(n) for naive repeated multiplication.
    //
    // These facts are why it works:
    //
    //  If n is even, then x^n = (x^2)^(n/2).
    //  If n is odd,  then x^n = x * x^(n-1),
    //   and applying the equation for even x gives
    //    x^n = x * (x^2)^((n-1) / 2).
    //
    //  Also, EVM division is flooring and
    //    floor[(n-1) / 2] = floor[n / 2].
    //
    function rpow(uint x, uint n) internal pure returns (uint z) {
        z = n % 2 != 0 ? x : RAY;

        for (n /= 2; n != 0; n /= 2) {
            x = rmul(x, x);

            if (n % 2 != 0) {
                z = rmul(z, x);
            }
        }
    }
}

contract ERC20Events {
    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);
}

contract ERC20 is ERC20Events {
    function totalSupply() public view returns (uint);
    function balanceOf(address guy) public view returns (uint);
    function allowance(address src, address guy) public view returns (uint);

    function approve(address guy, uint wad) public returns (bool);
    function transfer(address dst, uint wad) public returns (bool);
    function transferFrom(
        address src, address dst, uint wad
    ) public returns (bool);
}

contract DSTokenBase is ERC20, DSMath {
    uint256                                            _supply;
    mapping (address => uint256)                       _balances;
    mapping (address => mapping (address => uint256))  _approvals;

    constructor(uint supply) public {
        _balances[msg.sender] = supply;
        _supply = supply;
    }

    function totalSupply() public view returns (uint) {
        return _supply;
    }
    function balanceOf(address src) public view returns (uint) {
        return _balances[src];
    }
    function allowance(address src, address guy) public view returns (uint) {
        return _approvals[src][guy];
    }

    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint wad)
        public
        returns (bool)
    {
        if (src != msg.sender) {
            require(_approvals[src][msg.sender] >= wad, "ds-token-insufficient-approval");
            _approvals[src][msg.sender] = sub(_approvals[src][msg.sender], wad);
        }

        require(_balances[src] >= wad, "ds-token-insufficient-balance");
        _balances[src] = sub(_balances[src], wad);
        _balances[dst] = add(_balances[dst], wad);

        emit Transfer(src, dst, wad);

        return true;
    }

    function approve(address guy, uint wad) public returns (bool) {
        _approvals[msg.sender][guy] = wad;

        emit Approval(msg.sender, guy, wad);

        return true;
    }
}

contract DSToken is DSTokenBase(0), DSStop {

    bytes32  public  symbol;
    uint256  public  decimals = 18; // standard token precision. override to customize

    constructor(bytes32 symbol_) public {
        symbol = symbol_;
    }

    event Mint(address indexed guy, uint wad);
    event Burn(address indexed guy, uint wad);

    function approve(address guy) public stoppable returns (bool) {
        return super.approve(guy, uint(-1));
    }

    function approve(address guy, uint wad) public stoppable returns (bool) {
        return super.approve(guy, wad);
    }

    function transferFrom(address src, address dst, uint wad)
        public
        stoppable
        returns (bool)
    {
        if (src != msg.sender && _approvals[src][msg.sender] != uint(-1)) {
            require(_approvals[src][msg.sender] >= wad, "ds-token-insufficient-approval");
            _approvals[src][msg.sender] = sub(_approvals[src][msg.sender], wad);
        }

        require(_balances[src] >= wad, "ds-token-insufficient-balance");
        _balances[src] = sub(_balances[src], wad);
        _balances[dst] = add(_balances[dst], wad);

        emit Transfer(src, dst, wad);

        return true;
    }

    function push(address dst, uint wad) public {
        transferFrom(msg.sender, dst, wad);
    }
    function pull(address src, uint wad) public {
        transferFrom(src, msg.sender, wad);
    }
    function move(address src, address dst, uint wad) public {
        transferFrom(src, dst, wad);
    }

    function mint(uint wad) public {
        mint(msg.sender, wad);
    }
    function burn(uint wad) public {
        burn(msg.sender, wad);
    }
    function mint(address guy, uint wad) public auth stoppable {
        _balances[guy] = add(_balances[guy], wad);
        _supply = add(_supply, wad);
        emit Mint(guy, wad);
    }
    function burn(address guy, uint wad) public auth stoppable {
        if (guy != msg.sender && _approvals[guy][msg.sender] != uint(-1)) {
            require(_approvals[guy][msg.sender] >= wad, "ds-token-insufficient-approval");
            _approvals[guy][msg.sender] = sub(_approvals[guy][msg.sender], wad);
        }

        require(_balances[guy] >= wad, "ds-token-insufficient-balance");
        _balances[guy] = sub(_balances[guy], wad);
        _supply = sub(_supply, wad);
        emit Burn(guy, wad);
    }

    // Optional token name
    bytes32   public  name = "";

    function setName(bytes32 name_) public auth {
        name = name_;
    }
}

interface RequestableI {
    function applyRequestInRootChain(
        bool isExit,
        uint256 requestId,
        address requestor,
        bytes32 trieKey,
        bytes32 trieValue
    ) external returns (bool success);

    function applyRequestInChildChain(
        bool isExit,
        uint256 requestId,
        address requestor,
        bytes32 trieKey,
        bytes32 trieValue
    ) external returns (bool success);

}

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
    mapping(uint => bool) public appliedRequests;

    /* Events */
    event Request(bool _isExit, address indexed _requestor, bytes32 _trieKey, bytes32 _trieValue);

    constructor (bytes32 symbol_, address rootchain_) DSToken(symbol_) public {
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
        bytes32 trieValue
    ) public returns (bool success) {
        // TODO: adpot RootChain
        // require(msg.sender == address(rootchain));
        // require(!getRequestApplied(requestId)); // check double applying

        require(!appliedRequests[requestId]);

        if (trieKey == bytes32(1)) {
            _handleOwner(true, isExit, requestor, trieKey, trieValue);
        } else if (trieKey == bytes32(2)) {
            _handleStopped(true, isExit, requestor, trieKey, trieValue);
        } else if (trieKey == getBalanceTrieKey(requestor)) {
            _handleBalance(true, isExit, requestor, trieKey, trieValue);
        } else {
            revert();
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

        if (trieKey == bytes32(1)) {
            _handleOwner(false, isExit, requestor, trieKey, trieValue);
        } else if (trieKey == bytes32(2)) {
            _handleStopped(false, isExit, requestor, trieKey, trieValue);
        } else if (trieKey == getBalanceTrieKey(requestor)) {
            _handleBalance(false, isExit, requestor, trieKey, trieValue);
        } else {
            revert();
        }

        appliedRequests[requestId] = true;

        emit Request(isExit, requestor, trieKey, trieValue);
        return true;
    }

    function _handleOwner(
        bool isRootChain,
        bool isExit,
        address requestor,
        bytes32 trieKey,
        bytes32 trieValue
    ) internal {
        address newOwner = address(trieValue);

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
        bytes32 trieValue
    ) internal {
        bool newStopped = trieValue == 0x01;

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
        bytes32 trieValue
    ) internal {
        uint amount = uint(trieValue);

        if (isRootChain) {
            if (isExit) {
                _balances[requestor] = add(_balances[requestor], amount);
                _balances[this] = sub(_balances[this], amount);
            } else {
                require(amount <= _balances[requestor]);
                _balances[requestor] = sub(_balances[requestor], amount);
                _balances[this] = add(_balances[this], amount);
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
