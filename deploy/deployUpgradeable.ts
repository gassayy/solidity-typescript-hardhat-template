import { DeployFunction } from "hardhat-deploy/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { ethers, upgrades } from "hardhat"

const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms))

export const upgradeableDeploy = async function (
    deployer: string,
    hre: HardhatRuntimeEnvironment,
    initParams: any[],
    contractName: string
) {
    const ContractFactory = await ethers.getContractFactory(contractName)
    const contract = await upgrades.deployProxy(
        ContractFactory,
        initParams,
        { initializer: "initialize" }
    )
    await contract.waitForDeployment()
    
    console.log(`${contractName} deployed to:`, await contract.getAddress())

    // TODO：verify contracts is not working!
    // const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    //     await contract.getAddress()
    // )
    // console.log("Implementation address:", implementationAddress)

    // const initializeData = ContractFactory.interface.encodeFunctionData(
    //     "initialize",
    //     initParams
    // )
    // await hre.run("verify:verify", {
    //     address: implementationAddress,
    //     constructorArguments: [],
    //     contract: `contracts/${contractName}.sol:${contractName}`
    // })

    // await hre.run("verify:etherscan", {
    //     address: await contract.getAddress(),
    //     contract: "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy",
    //     constructorArguments: [implementationAddress, initializeData]
    // }).catch(err => {
    //     console.log("Error verifying proxy:", err)
    // })
}
