import { expect } from "chai";
import { deployments, ethers } from "hardhat";


describe("FeeManager", () => {
    const setupFixture = deployments.createFixture(async () => {
        await deployments.fixture();

        const [deployer, user, recipient] = await ethers.getSigners();

        // Deploy a mock ERC20 token for testing
        const paymentToken = await ethers.deployContract(
            "BasicERC20",
            ["TestToken", "TT", deployer.address],
            deployer
        );

        // Deploy FeeManager with the payment token and initial bytes per token rate
        const feeManager = (await ethers.deployContract(
            "FeeManager",
            [ 
                paymentToken.getAddress(), 
                100, // 100 bytes per token
                deployer.address
            ],
            deployer
        ));

        return {
            feeManager,
            paymentToken,
            deployer,
            user,
            recipient,
        };
    });

    it("Should set and get bytes per token correctly", async () => {
        const { feeManager, deployer } = await setupFixture();
        console.log("fee manager address", await feeManager.getAddress());
        expect(await feeManager.getBytesPerToken()).to.equal(100);

        await feeManager.connect(deployer).setBytesPerToken(200);
        expect(await feeManager.getBytesPerToken()).to.equal(200);
    });

    it("Should set and get payment token correctly", async () => {
        const { feeManager, paymentToken, deployer } = await setupFixture();

        expect(await feeManager.getPaymentToken()).to.equal(await paymentToken.getAddress());

        const newPaymentToken = await ethers.deployContract(
            "BasicERC20",
            ["NewToken", "NT", deployer.address],
            deployer
        );

        await feeManager.connect(deployer).setPaymentToken(newPaymentToken.getAddress());
        expect(await feeManager.getPaymentToken()).to.equal(await newPaymentToken.getAddress());
    });

    it("Should estimate fees correctly", async () => {
        const { feeManager } = await setupFixture();

        const requestBytes = 500;
        const maxResponseBytes = 300;
        const expectedFee = (requestBytes + maxResponseBytes) / 100;

        expect(await feeManager.estimateFee(requestBytes, maxResponseBytes)).to.equal(expectedFee);
    });

    it("Should allow owner to claim fees", async () => {
        const { feeManager, paymentToken, deployer, recipient } = await setupFixture();

        // Mint tokens to FeeManager for testing
        await paymentToken.mint(feeManager.getAddress(), 1000);

        expect(await paymentToken.balanceOf(await recipient.getAddress())).to.equal(0);

        await feeManager.connect(deployer).claimFee(500, await recipient.getAddress());

        expect(await paymentToken.balanceOf(await recipient.getAddress())).to.equal(500);
    });

    it("Should revert claim fee if insufficient balance", async () => {
        const { feeManager, recipient } = await setupFixture();

        await expect(
            feeManager.claimFee(1000, await recipient.getAddress())
        ).to.be.revertedWithCustomError(feeManager, "InsufficientBalance");
    });

    it("Should transfer payment token correctly", async () => {
        const { feeManager, paymentToken, deployer, user, recipient } = await setupFixture();

        // Mint tokens to user for testing
        await paymentToken.mint(await user.getAddress(), 1000);

        expect(await paymentToken.balanceOf(await recipient.getAddress())).to.equal(0);

        await paymentToken.connect(user).approve(feeManager.getAddress(), 500);
        await feeManager.connect(deployer).transferPaymentToken(await user.getAddress(), await recipient.getAddress(), 500);

        expect(await paymentToken.balanceOf(await recipient.getAddress())).to.equal(500);
    });

    it("Should revert transfer if insufficient balance", async () => {
        const { feeManager, user, recipient } = await setupFixture();

        await expect(
            feeManager.transferPaymentToken(await user.getAddress(), await recipient.getAddress(), 1000)
        ).to.be.revertedWithCustomError(feeManager, "InsufficientBalance");
    });
}); 