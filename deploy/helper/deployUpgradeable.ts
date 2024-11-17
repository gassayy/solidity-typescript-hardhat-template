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
    // Deploy the upgradeable contract
    const ContractFactory = await ethers.getContractFactory(contractName)
    const contract = await upgrades.deployProxy(
        ContractFactory,
        initParams,
        { initializer: "initialize" }
    )
    await contract.waitForDeployment()
    
    console.log(`${contractName} deployed to:`, await contract.getAddress())

    // Get the implementation address
    const implementationAddress = await upgrades.erc1967.getImplementationAddress(
        await contract.getAddress()
    )
    console.log("Implementation address:", implementationAddress)

    // Encode initialization data for verification
    const initializeData = ContractFactory.interface.encodeFunctionData(
        "initialize",
        initParams
    )

    // Add delay to allow etherscan to index the contract
    await delay(20000)
    // Verify the proxy contract
    await hre.run("verify:verify", {
        address: await contract.getAddress(),
        contract: "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy",
        constructorArguments: [implementationAddress, initializeData]
    })
}
