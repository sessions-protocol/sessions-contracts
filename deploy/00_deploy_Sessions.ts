import { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts();

  const lensHub = "0xd7B3481De00995046C7850bCe9a5196B7605c367";
  const sessionNFTImpl = "0x0000000000000000000000000000000000000000";

  const gov = deployer;
  
  await deploy('Sessions', {
    from: deployer,
    args: [lensHub, sessionNFTImpl, gov],
    log: true
  })

}
export default func
