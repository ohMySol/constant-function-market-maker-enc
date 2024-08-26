import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { network } from "hardhat";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;
  const deployed = await deploy("CFMM", {
    from: deployer,
    args: [process.env.TOKEN_A_LOCAL, process.env.TOKEN_B_LOCAL],
    log: true,
  });
  
  console.log(`CFMM contract on ${network.name}: `, deployed.address);
};

export default func;
func.id = "deploy_cfmm"; // id required to prevent reexecution
func.tags = ["CFMM"];
