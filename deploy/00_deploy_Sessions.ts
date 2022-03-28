import { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts();

  const lensHub = "0xd7B3481De00995046C7850bCe9a5196B7605c367";
  
  await deploy('Sessions', {
    from: deployer,
    args: [lensHub],
    proxy: true,
    log: true
  })

}
export default func
