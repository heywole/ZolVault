// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ZolPool - Simulated yield pool for LiteForge testnet.
// On mainnet replace with real LitSwap / Silver Standard pools.
// Yield = principal x APY x time elapsed, paid from seeded reserve.

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract ZolPool {
    address public token;
    string  public poolName;
    uint256 public apy;
    uint256 public lastHarvest;
    address public owner;

    mapping(address => uint256) public deposited;
    uint256 public totalDeposited;

    event Deposited(address vault, uint256 amt);
    event Withdrawn(address vault, uint256 amt);
    event Harvested(address vault, uint256 yld);

    constructor(address _token, string memory _name, uint256 _apy) {
        token       = _token;
        poolName    = _name;
        apy         = _apy;
        lastHarvest = block.timestamp;
        owner       = msg.sender;
    }

    function deposit(uint256 amount) external {
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        deposited[msg.sender] += amount;
        totalDeposited        += amount;
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(deposited[msg.sender] >= amount, "insufficient");
        deposited[msg.sender] -= amount;
        totalDeposited        -= amount;
        IERC20(token).transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function harvest() external returns (uint256 yld) {
        uint256 principal = deposited[msg.sender];
        if (principal == 0) return 0;
        uint256 elapsed = block.timestamp - lastHarvest;
        yld = (principal * apy * elapsed) / (10000 * 365 days);
        lastHarvest = block.timestamp;
        uint256 reserve = IERC20(token).balanceOf(address(this));
        if (yld > 0 && reserve > totalDeposited + yld) {
            IERC20(token).transfer(msg.sender, yld);
        } else {
            yld = 0;
        }
        emit Harvested(msg.sender, yld);
    }

    function getApy() external view returns (uint256) { return apy; }
    function balanceOf(address a) external view returns (uint256) { return deposited[a]; }
    function setApy(uint256 _apy) external { require(msg.sender == owner); apy = _apy; }
}
