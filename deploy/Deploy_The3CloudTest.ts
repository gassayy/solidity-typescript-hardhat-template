import { DeployFunction } from "hardhat-deploy/types"
import { HardhatRuntimeEnvironment } from "hardhat/types"
import { ethers } from "hardhat"

// hh deploy --tags tcc-deploy --network sepolia
// >> 0xc7A26aa53B2EBe73F713FD33Eb9c3EF94560C05b
// hh --network sepolia verify 0xc7A26aa53B2EBe73F713FD33Eb9c3EF94560C05b "The3CloudCoin" "TCC" "0x3fcbAf4822e7c7364E43aEc8253dfc888b9235bB"
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
	// Get signers
	const [deployer] = await ethers.getSigners()
	const { owner } = await hre.getNamedAccounts()

    console.log("Deploying The3CloudTest...")
}
export default func
func.tags = ["the3cloudtest"]