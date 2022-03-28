import { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts();

  const sessions = "0x54f6Fb3E799ed5A1FedeeF26E647801911BcB36d";

  await deploy('SessionNFT', {
    from: deployer,
    args: [sessions],
    log: true
  })

}
export default func
