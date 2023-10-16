const { ethers } = require("hardhat");

async function main() {

  // 部署工厂合约。
  const MultiSignatureFactory = await ethers.deployContract("MultiSignatureFactory", { gasLimit: "0x1000000" });
  await MultiSignatureFactory.waitForDeployment();
  console.log(`MultiSignature Factory deployed to ${MultiSignatureFactory.target}`);

  // 部署多签权重值钱包的逻辑合约。
  const MultiSignatureWeight = await ethers.deployContract("MultiSignatureWeight", { gasLimit: "0x1000000" });
  await MultiSignatureWeight.waitForDeployment();
  console.log(`MultiSignature Weight deployed to ${MultiSignatureWeight.target}`);

}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})