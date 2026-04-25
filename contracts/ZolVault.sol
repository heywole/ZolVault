// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// ZolVault - Autonomous LTC Yield Engine
// Network: LitVM LiteForge Testnet
// Fee: 2% of yield only. Principal always returned 100%.

interface IPool {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function harvest() external returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function getApy() external view returns (uint256);
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract ZolVault {

    address public immutable developer;
    address public agent;
    address public token;

    uint256 public constant DEV_FEE = 200;
    uint256 public constant BPS     = 10000;
    uint256 public constant MIN_DEP = 1e15;

    bool    public paused;
    uint256 public totalPrincipal;
    uint256 public totalShares;
    uint256 public totalCompounds;
    uint256 public devFeesEarned;

    enum Risk { Safe, Medium, High }

    struct User {
        uint256 principal;
        uint256 shares;
        uint256 yieldNet;
        uint256 yieldClaimed;
        Risk    risk;
        uint256 depositedAt;
        bool    active;
    }

    mapping(address => User) public users;
    address[] public allUsers;
    mapping(Risk => address) public activePool;
    address[] public approvedPools;

    event Deposited(address indexed user, uint256 amount, Risk risk);
    event Withdrawn(address indexed user, uint256 principal, uint256 yieldNet);
    event Compounded(uint256 gross, uint256 devFee, uint256 netToUsers);
    event Rotated(Risk risk, address newPool);

    modifier onlyDev()   { require(msg.sender == developer, "not dev"); _; }
    modifier onlyAgent() { require(msg.sender == agent || msg.sender == developer, "not agent"); _; }
    modifier live()      { require(!paused, "paused"); _; }

    constructor(address _token, address _agent) {
        developer = msg.sender;
        token     = _token;
        agent     = _agent;
    }

    function deposit(uint256 amount, Risk risk) external live {
        require(amount >= MIN_DEP, "below minimum");
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        uint256 shares = (totalShares == 0 || totalPrincipal == 0)
            ? amount
            : (amount * totalShares) / totalPrincipal;

        if (!users[msg.sender].active) {
            allUsers.push(msg.sender);
            users[msg.sender].active = true;
        }

        User storage u = users[msg.sender];
        u.principal   += amount;
        u.shares      += shares;
        u.risk         = risk;
        u.depositedAt  = block.timestamp;

        totalPrincipal += amount;
        totalShares    += shares;

        address pool = activePool[risk];
        if (pool != address(0)) {
            IERC20(token).approve(pool, amount);
            IPool(pool).deposit(amount);
        }

        emit Deposited(msg.sender, amount, risk);
    }

    function withdraw() external {
        User storage u = users[msg.sender];
        require(u.active && u.principal > 0, "no deposit");

        uint256 principal = u.principal;
        uint256 yld       = u.yieldNet;

        totalPrincipal -= principal;
        totalShares    -= u.shares;
        u.principal = 0;
        u.shares    = 0;
        u.yieldNet  = 0;

        address pool = activePool[u.risk];
        if (pool != address(0)) IPool(pool).withdraw(principal);

        IERC20(token).transfer(msg.sender, principal + yld);
        if (yld > 0) u.yieldClaimed += yld;

        emit Withdrawn(msg.sender, principal, yld);
    }

    function claimYield() external {
        User storage u = users[msg.sender];
        require(u.yieldNet > 0, "no yield");
        uint256 amount = u.yieldNet;
        u.yieldNet      = 0;
        u.yieldClaimed += amount;
        IERC20(token).transfer(msg.sender, amount);
    }

    function emergencyExit() external {
        User storage u = users[msg.sender];
        require(u.active, "no deposit");
        uint256 principal = u.principal;
        uint256 yld       = u.yieldNet;
        if (principal > 0) {
            totalPrincipal -= principal;
            totalShares    -= u.shares;
        }
        u.principal = 0;
        u.shares    = 0;
        u.yieldNet  = 0;
        address pool = activePool[u.risk];
        if (pool != address(0) && principal > 0) IPool(pool).withdraw(principal);
        uint256 total = principal + yld;
        if (total > 0) IERC20(token).transfer(msg.sender, total);
    }

    function compound() external onlyAgent live {
        require(totalPrincipal > 0, "no deposits");

        uint256 gross = 0;
        for (uint256 i; i < approvedPools.length; i++) {
            try IPool(approvedPools[i]).harvest() returns (uint256 y) {
                gross += y;
            } catch {}
        }
        if (gross == 0) return;

        uint256 fee = (gross * DEV_FEE) / BPS;
        uint256 net = gross - fee;

        devFeesEarned += fee;
        IERC20(token).transfer(developer, fee);

        for (uint256 i; i < allUsers.length; i++) {
            User storage u = users[allUsers[i]];
            if (u.shares == 0) continue;
            u.yieldNet += (net * u.shares) / totalShares;
        }

        totalCompounds++;
        emit Compounded(gross, fee, net);
    }

    function rotateStrategy(Risk risk, address newPool) external onlyAgent {
        require(_approved(newPool), "pool not approved");
        address old = activePool[risk];
        if (old == newPool) return;
        if (old != address(0)) {
            uint256 bal = IPool(old).balanceOf(address(this));
            if (bal > 0) IPool(old).withdraw(bal);
        }
        uint256 avail = IERC20(token).balanceOf(address(this));
        if (avail > 0) {
            IERC20(token).approve(newPool, avail);
            IPool(newPool).deposit(avail);
        }
        activePool[risk] = newPool;
        emit Rotated(risk, newPool);
    }

    function getUser(address u) external view returns (
        uint256 principal, uint256 yieldNet, uint256 yieldClaimed,
        uint8 risk, uint256 depositedAt, bool active
    ) {
        User storage x = users[u];
        return (x.principal, x.yieldNet, x.yieldClaimed, uint8(x.risk), x.depositedAt, x.active);
    }

    function getTVL()   external view returns (uint256) { return totalPrincipal; }
    function getUsers() external view returns (uint256) { return allUsers.length; }
    function getPools() external view returns (address[] memory) { return approvedPools; }

    function addPool(address p)  external onlyDev { require(!_approved(p)); approvedPools.push(p); }
    function setAgent(address a) external onlyDev { agent = a; }
    function setPaused(bool p)   external onlyDev { paused = p; }

    function _approved(address p) internal view returns (bool) {
        for (uint256 i; i < approvedPools.length; i++) {
            if (approvedPools[i] == p) return true;
        }
        return false;
    }
}
