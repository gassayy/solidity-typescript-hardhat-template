import { expect } from "chai";
import { deployments, getNamedAccounts, ethers } from "hardhat";
import { Contract } from "ethers";

describe("ContractA and ContractB", () => {
  const setupFixture = deployments.createFixture(async () => {
    await deployments.fixture();
    const signers = await getNamedAccounts();
    const accounts = await ethers.getSigners();

    // Deploy a mock ERC20 token for testing
    const token = await ethers.deployContract(
      "BasicERC20",
      ["TestToken", "TT", signers.deployer],
      await ethers.getSigner(signers.deployer)
    );



    console.log("token", await token.getAddress());

    // Deploy ContractB first
    const contractB = await ethers.deployContract(
      "ContractB",
      [token.getAddress()],
      await ethers.getSigner(signers.deployer)
    );

    console.log("contractB", await contractB.getAddress());

    // Deploy ContractA with the address of ContractB
    const contractA = await ethers.deployContract(
      "ContractA",
      [token.getAddress(), contractB.getAddress()],
      await ethers.getSigner(signers.deployer)
    );

    console.log("contractA", await contractA.getAddress());

    return {
      token,
      contractA,
      contractB,
      accounts,
      deployer: signers.deployer,
    };
  });

  it("Should deploy contracts with correct initial setup", async () => {
    const { contractA, contractB, token } = await setupFixture();

    expect(await contractA.paymentToken()).to.equal(await token.getAddress());
    expect(await contractB.paymentToken()).to.equal(await token.getAddress());
  });


  it("Should transfer tokens from ContractA to ContractB", async () => {
    const { contractA, contractB, token, accounts } = await setupFixture();

    // Mint tokens to ContractA
    await token.mint(contractA.getAddress(), 1000);

    // Check initial balances
    expect(await token.balanceOf(contractA.getAddress())).to.equal(1000);
    expect(await token.balanceOf(contractB.getAddress())).to.equal(0);

    // Call foo on ContractA, which should trigger bar on ContractB
    await contractA.foo(500, { value: ethers.parseEther("1") });

    // Check final balances
    expect(await token.balanceOf(contractA.getAddress())).to.equal(500);
    expect(await token.balanceOf(contractB.getAddress())).to.equal(500);
  });

  it("Should revert if ContractA has insufficient token balance", async () => {
    const { contractA, accounts } = await setupFixture();

    // Attempt to call foo with more tokens than ContractA has
    await expect(
      contractA.foo(1000, { value: ethers.parseEther("1") })
    ).to.be.revertedWith("Insufficient token balance");
  });
}); 