import { HardhatRuntimeEnvironment } from 'hardhat/types'
import type { DeployFunction } from 'hardhat-deploy/types'

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments

  const { deployer } = await getNamedAccounts();

  const profile = "0x827b0808b1cf350d7962a4f9bcb42927b68d3ceb";
  
  await deploy('Sessions', {
    from: deployer,
    args: [profile],
    proxy: true,
    log: true
  })

}
/**
 * Sessions_Implementation" deployed at 0x7aF7e80a452470FfAf010243a019d9Fbbb9fF025
 * Sessions_Proxy deployed at 0x82295BB8f16a5910303B214B5e4a844eF3091381
 */
func.tags = ['Session'];
export default func
