// scripts/deployAll.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const fee = ethers.parseEther("0.01");
  const deployer = "0x2467BeE786aCdd26D9BcD7759C8464463fD33549";
  const feeCollector = "0x2467BeE786aCdd26D9BcD7759C8464463fD33549";
  const termsHash = ethers.keccak256(ethers.toUtf8Bytes("RealtyArmy Default Escrow Terms"));

  const contracts = [
    { name: "Mortgage", args: [100] }, // 1%
    { name: "DisputeResolution", args: [fee] },
    { name: "FractionalOwnership", args: [
        "Fractional Home", 
        "FRHOME", 
        "456 Realty Lane", 
        1000, 
        ethers.parseEther("1"), 
        200, 
        feeCollector
    ]},
    { name: "Crowdfunding", args: [feeCollector, 300] }, // 3%
    { name: "Lease", args: [fee] },
    { name: "TitleRegistry", args: [fee, feeCollector] },
    { name: "MultiEscrowManager", args: [feeCollector, 250, 100, termsHash] },
    { name: "PropertyManagement", args: [150] }, // 1.5%
    { name: "SalesEscrow", args: [300, feeCollector] } // 3%
  ];

  for (const contract of contracts) {
    const ContractFactory = await ethers.getContractFactory(contract.name);
    const instance = await upgrades.deployProxy(
      ContractFactory,
      contract.args,
      { kind: "uups" }
    );
    await instance.waitForDeployment();
    console.log(`${contract.name} deployed to:`, await instance.getAddress());
  }
}

main().catch((error) => {
  console.error("Deployment failed:", error);
  process.exitCode = 1;
});
