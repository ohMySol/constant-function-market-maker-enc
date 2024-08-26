import type { CFMM } from "../../types";
import { getSigners } from "../signers";
import { ethers } from "hardhat";


export async function deployEncryptedCFMMFixture(): Promise<CFMM> {
  const signers = await getSigners();
  const tokenA = "0xeD486acfB278394791b2350BaEb1100f2CF0a189"
  const tokenB = "0xC2ddfA03C9e106acdCE10d404404B7dAE901C74F"
  
  const contractFactory = await ethers.getContractFactory("CFMM");
  const contract = await contractFactory.connect(signers.alice).deploy(tokenA, tokenB); // City of Zama's battle
  await contract.waitForDeployment();

  return contract;
}
