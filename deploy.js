// deploy.js — run once: npm run deploy
// Deploys all contracts to LiteForge testnet and saves addresses to addresses.json

const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
  const [dev] = await ethers.getSigners();
  const bal   = await ethers.provider.getBalance(dev.address);

  console.log("\n══════════════════════════════════════");
  console.log("  ZolVault — Deploying to LiteForge");
  console.log("══════════════════════════════════════");
  console.log("Your wallet:", dev.address);
  console.log("Balance:    ", ethers.formatEther(bal), "zkLTC");
  console.log("Explorer:    https://liteforge.explorer.caldera.xyz\n");

  // 1. Test token
  console.log("1/5  Deploying TestZkLTC...");
  const Token  = await ethers.getContractFactory("TestZkLTC");
  const token  = await Token.deploy();
  await token.waitForDeployment();
  const tokenAddr = await token.getAddress();
  console.log("     ✓", tokenAddr);

  // 2. Three yield pools
  console.log("2/5  Deploying ZolPools...");
  const Pool  = await ethers.getContractFactory("ZolPool");
  const pool1 = await Pool.deploy(tokenAddr, "Safe Pool",   800);   // 8% APY
  await pool1.waitForDeployment();
  const pool2 = await Pool.deploy(tokenAddr, "Medium Pool", 1500);  // 15% APY
  await pool2.waitForDeployment();
  const pool3 = await Pool.deploy(tokenAddr, "High Pool",   3500);  // 35% APY
  await pool3.waitForDeployment();
  const [p1, p2, p3] = [await pool1.getAddress(), await pool2.getAddress(), await pool3.getAddress()];
  console.log("     ✓ Safe Pool  (8%)  ", p1);
  console.log("     ✓ Medium Pool (15%)", p2);
  console.log("     ✓ High Pool  (35%)", p3);

  // 3. Seed pools with tokens so they can pay out yield
  console.log("3/5  Seeding pools with reserve tokens...");
  const seed = ethers.parseEther("500000");
  for (const addr of [p1, p2, p3]) {
    await (await token.transfer(addr, seed)).wait();
  }
  console.log("     ✓ Each pool seeded with 500,000 zkLTC");

  // 4. Deploy vault
  console.log("4/5  Deploying ZolVault...");
  const Vault  = await ethers.getContractFactory("ZolVault");
  const vault  = await Vault.deploy(tokenAddr, dev.address); // dev.address is also agent
  await vault.waitForDeployment();
  const vaultAddr = await vault.getAddress();
  console.log("     ✓", vaultAddr);

  // 5. Register pools in vault + set defaults
  console.log("5/5  Registering pools...");
  await (await vault.addPool(p1)).wait();
  await (await vault.addPool(p2)).wait();
  await (await vault.addPool(p3)).wait();
  await (await vault.rotateStrategy(0, p1)).wait(); // Safe   → pool1
  await (await vault.rotateStrategy(1, p2)).wait(); // Medium → pool2
  await (await vault.rotateStrategy(2, p3)).wait(); // High   → pool3
  console.log("     ✓ Pools registered and strategies set");

  // Save addresses
  const out = {
    network:    "LitVM LiteForge Testnet",
    chainId:    (await ethers.provider.getNetwork()).chainId.toString(),
    rpc:        "https://liteforge.rpc.caldera.xyz",
    explorer:   "https://liteforge.explorer.caldera.xyz",
    token:      tokenAddr,
    vault:      vaultAddr,
    pools: { safe: p1, medium: p2, high: p3 },
    developer:  dev.address,
    deployedAt: new Date().toISOString(),
  };
  fs.writeFileSync("addresses.json", JSON.stringify(out, null, 2));

  console.log("\n══════════════════════════════════════");
  console.log("  DONE — addresses saved to addresses.json");
  console.log("══════════════════════════════════════");
  console.log("Token:  ", tokenAddr);
  console.log("Vault:  ", vaultAddr);
  console.log("Dev fee: 2% of yield → your wallet automatically");
  console.log("\nNow open index.html and paste the addresses");
  console.log("from addresses.json into the ADDRESSES section at the top.");
  console.log("══════════════════════════════════════\n");
}

main().catch(e => { console.error(e); process.exit(1); });
