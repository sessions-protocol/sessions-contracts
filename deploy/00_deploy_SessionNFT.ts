import { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts();

  const sessions = "0xF3bF2EA8Df05716a2e5EC39A747Cb54726a49fcE";

  await deploy('SessionNFT', {
    from: deployer,
    args: [sessions],
    log: true
  })

}
export default func
