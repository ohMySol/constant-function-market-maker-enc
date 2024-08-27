import type { EncryptedTokenA } from "../../types";
import type { EncryptedTokenB } from "../../types";
import { getSigners } from "../signers";
import { ethers } from "hardhat";


export async function deployEncryptedTokenAFixture(): Promise<EncryptedTokenA> {
  const signers = await getSigners();

  const contractFactory = await ethers.getContractFactory("EncryptedTokenA");
  const contract = await contractFactory.connect(signers.alice).deploy("TokenA", "TA"); // City of Zama's battle
  await contract.waitForDeployment();

  return contract;
}

export async function deployEncryptedTokenBFixture(): Promise<EncryptedTokenB> {
  const signers = await getSigners();

  const contractFactory = await ethers.getContractFactory("EncryptedTokenA");
  const contract = await contractFactory.connect(signers.alice).deploy("TokenB", "TB"); // City of Zama's battle
  await contract.waitForDeployment();

  return contract;
}
