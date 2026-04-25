// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// TestZkLTC - Test token for ZolVault on LiteForge testnet.
// Users call faucet() to receive 1000 free tokens for testing.
// On mainnet: replace with real bridged zkLTC from LitVM.

contract TestZkLTC {
    string  public name     = "Test zkLTC";
    string  public symbol   = "zkLTC";
    uint8   public decimals = 18;
    uint256 public totalSupply;
    address public owner;

    mapping(address => uint256)                     public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => bool)                        public claimed;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner_, address indexed spender, uint256 value);

    constructor() {
        owner = msg.sender;
        _mint(msg.sender, 10000000 * 1e18);
    }

    function faucet() external {
        require(!claimed[msg.sender], "Already claimed. Check your wallet.");
        claimed[msg.sender] = true;
        _mint(msg.sender, 1000 * 1e18);
    }

    function hasClaimed(address a) external view returns (bool) { return claimed[a]; }

    function mint(address to, uint256 amount) external {
        require(msg.sender == owner);
        _mint(to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "allowance exceeded");
        allowance[from][msg.sender] -= amount;
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "insufficient balance");
        balanceOf[from] -= amount;
        balanceOf[to]   += amount;
        emit Transfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply    += amount;
        balanceOf[to]  += amount;
        emit Transfer(address(0), to, amount);
    }
}
