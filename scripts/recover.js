// recover.js — scans 50,000 blocks back to find your deployed contracts
const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  const provider   = ethers.provider;

  console.log("Wallet:", deployer.address);

  const currentBlock = await provider.getBlockNumber();
  const startBlock   = Math.max(0, currentBlock - 50000);
  console.log(`Scanning blocks ${startBlock} to ${currentBlock} (${currentBlock - startBlock} blocks)...\n`);

  const contracts = [];

  for (let b = startBlock; b <= currentBlock; b++) {
    try {
      const block = await provider.getBlock(b, true);
      if (!block || !block.transactions) continue;

      for (const tx of block.transactions) {
        if (
          tx.from &&
          tx.from.toLowerCase() === deployer.address.toLowerCase() &&
          tx.to === null
        ) {
          const receipt = await provider.getTransactionReceipt(tx.hash);
          if (receipt && receipt.contractAddress) {
            console.log(`Found contract at block ${b}: ${receipt.contractAddress}`);
            contracts.push({
              address: receipt.contractAddress,
              block:   b,
              tx:      tx.hash,
            });
          }
        }
      }
    } catch (e) { /* skip */ }
  }

  console.log(`\nTotal contracts found: ${contracts.length}`);
  contracts.forEach((c, i) => {
    console.log(`  ${i + 1}. ${c.address}  (block ${c.block})`);
  });

  if (contracts.length >= 5) {
    const recovered = {
      token:  contracts[0].address,
      pools: {
        safe:   contracts[1].address,
        medium: contracts[2].address,
        high:   contracts[3].address,
      },
      vault:  contracts[4].address,
    };
    const fs = require("fs");
    fs.writeFileSync("addresses.json", JSON.stringify(recovered, null, 2));
    console.log("\naddresses.json saved:");
    console.log(JSON.stringify(recovered, null, 2));
  }
}

main().catch(console.error);
