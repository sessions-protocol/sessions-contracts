import { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts();

  const sessions = "0x6dc0424c5beb6bfadd150633e2e99522ddc0802d";

  await deploy('SessionNFT', {
    from: deployer,
    args: [sessions],
    log: true
  })

}
export default func
