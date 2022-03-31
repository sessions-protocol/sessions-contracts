import { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts();

  const sessions = "0xD25bB78d4750458BC564b21FbfF3566294FAF560";

  await deploy('SessionNFT', {
    from: deployer,
    args: [sessions],
    log: true
  })

}
func.tags = ['NFT'];
export default func
