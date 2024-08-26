import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { network } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const tokenNames = ["EncryptedTokenA", "EncryptedTokenB"]
  for (let i = 0; i < tokenNames.length; i++) { 
    const deployed = await deploy(tokenNames[i], {
      from: deployer,
      args: [tokenNames[i], "TT"],
      log: true,
    });
  
    console.log(`${tokenNames[i]} contract on ${network.name}: `, deployed.address);
  }
  
};

export default func;
func.id = "deploy_confidentialERC20"; // id required to prevent reexecution
func.tags = ["MyERC20"];
