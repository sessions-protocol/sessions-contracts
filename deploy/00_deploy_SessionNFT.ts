import { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts();

  const sessions = "0xf19C27C92EEA361F8e2FD246283CD058e4d78F00";

  await deploy('SessionNFT', {
    from: deployer,
    args: [sessions],
    log: true
  })

}
export default func
