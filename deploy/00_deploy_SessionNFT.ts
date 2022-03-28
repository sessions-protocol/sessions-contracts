import { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts();

  const sessions = "0x3a0494b31EE26705a8Cca6f42703Ec70E45b016a";

  await deploy('SessionNFT', {
    from: deployer,
    args: [sessions],
    log: true
  })

}
export default func
