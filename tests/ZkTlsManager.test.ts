import { expect } from "chai"
import { deployments, ethers, upgrades } from "hardhat"
import { ZkTlsManager } from "../typechain-types"

describe("ZkTlsManager", function () {

    const setupFixture = deployments.createFixture(async () => {
        await deployments.fixture();
        const [owner, account1, account2] = await ethers.getSigners();

        const tokenWeiPerBytes = ethers.parseUnits("1", "gwei");
        const ZkTlsManagerFactory = await ethers.getContractFactory("ZkTlsManager");
        const zkTlsManager = await upgrades.deployProxy(
          ZkTlsManagerFactory, [BigInt(tokenWeiPerBytes.toString()), owner.address], { initializer: "initialize" }
        );
        await zkTlsManager.waitForDeployment();

        console.log("owner: ", owner.address);
        console.log("account1: ", account1.address);
        console.log("account2: ", account2.address);
        console.log("zkTlsManager proxy: ", await zkTlsManager.getAddress());

        return { zkTlsManager, owner, account1, account2, tokenWeiPerBytes }
    })

    describe("Deployment", () => {
        it("should set the correct token wei per bytes and owner", async() => {
            const { zkTlsManager, owner, tokenWeiPerBytes } = await setupFixture();
            expect(await zkTlsManager.getTokenWeiPerBytes()).to.equal(BigInt(tokenWeiPerBytes.toString()));
            expect(await zkTlsManager.owner()).to.equal(owner.address);
        })
    })
}) 