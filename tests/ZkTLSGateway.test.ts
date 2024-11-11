import { expect } from "chai";
import { deployments, ethers } from "hardhat";
import { ZkTlsGateway, IERC20 } from "../typechain-types";

describe("ZkTlsGateway", () => {
    const setupFixture = deployments.createFixture(async () => {
        await deployments.fixture();

        const [owner, user] = await ethers.getSigners();

        const forwardingContract = await ethers.deployContract("Forwarding");
        const paymentToken = await ethers.deployContract("BasicERC20", ["Payment Token", "PT", owner.address]);

        const zkTlsGateway = await ethers.deployContract("ZkTlsGateway", [
            await forwardingContract.getAddress(),
            await paymentToken.getAddress(),
        ]);

        // test data generation
        const requestInfo = {
          remote: "https://httpbin.org",
          serverName: "httpbin.org",
          requestTemplateHash: ethers.randomBytes(32),
          responseTemplateHash: ethers.randomBytes(32),
          fields: [ethers.randomBytes(32), ethers.randomBytes(32), ethers.randomBytes(32)],
          values: [ethers.randomBytes(32), ethers.randomBytes(32), ethers.randomBytes(32)],
          data: [ethers.randomBytes(32), ethers.randomBytes(32), ethers.randomBytes(32)],
        };

        const feeConfig = {
          fee: ethers.parseEther("4"),
          maxResponseBytes: 1024 * 10,
          encryptedKey: ethers.ZeroHash,
        };

        const genRequestId = (clientAddress: string, nonce: number) => {
            const inputSeed = ethers.keccak256(ethers.AbiCoder.encode(["address", "uint256"], [clientAddress, nonce]));
            return zkTlsGateway._generateRequestId(nonce);
        };

        return {
            zkTlsGateway,
            forwardingContract,
            paymentToken,
            requestInfo,
            feeConfig,
            owner,
            user,
        };
    });

    describe("Deployment", () => {
        it("should set functions", async () => {
            const { zkTlsGateway, forwardingContract, paymentToken } = await setupFixture();

            const config = await zkTlsGateway.getConfiguration();
            expect(config.paymentToken).to.equal(await paymentToken.getAddress());
        });
    });

    // describe.only("Request TLS Call", () => {
    //     it("should create a request and emit events", async () => {
    //         const { zkTlsGateway, user, requestInfo, feeConfig } = await setupFixture();

    //         await zkTlsGateway.connect(user).requestTLSCallTemplate(
    //           requestInfo.remote,
    //           requestInfo.serverName,
    //           feeConfig.encryptedKey,
    //           requestInfo,
    //           feeConfig.fee,
    //           feeConfig.maxResponseBytes
    //         )
    //         const tx = await zkTlsGateway.connect(user).requestTLSCallTemplate(
    //           requestInfo.remote,
    //           requestInfo.serverName, 
    //           feeConfig.encryptedKey,
    //           requestInfo,
    //           feeConfig.fee,
    //           feeConfig.maxResponseBytes,
    //           { value: 1000000n }
    //         );
            
    //         console.log("tx", tx.value);

    //         await expect(tx).to
    //             .emit(zkTlsGateway, "RequestTLSCallBegin")
    //             .withArgs(
    //                 "0x0", // 这里怎么能match anyvalue？
    //                 requestInfo.requestTemplateHash,
    //                 ethers.ZeroHash,
    //                 requestInfo.responseTemplateHash,
    //                 requestInfo.remote,
    //                 requestInfo.serverName,
    //                 feeConfig.encryptedKey,
    //                 feeConfig.maxResponseBytes
    //             );
    //     });
    // });

    // describe("Delivery Response", () => {
    //     it("should process a response and emit GasUsed", async () => {
    //         const { zkTlsGateway, user, forwardingContract } = await setupFixture();

    //         const requestId = ethers.randomBytes(32);
    //         const requestHash = ethers.randomBytes(32);
    //         const response = ethers.randomBytes(256);

    //         // Simulate a request being made
    //         await zkTlsGateway.connect(user).requestTLSCall(
    //             "https://example.com",
    //             "example.com",
    //             ethers.randomBytes(32),
    //             [ethers.randomBytes(32)],
    //             ethers.parseEther("0.1"),
    //             1024,
    //             { value: ethers.parseEther("0.1") }
    //         );

    //         await expect(
    //             zkTlsGateway.connect(user).deliveryResponse(
    //                 requestId,
    //                 requestHash,
    //                 response,
    //                 { value: ethers.parseEther("0.1") }
    //             )
    //         )
    //             .to.emit(zkTlsGateway, "GasUsed")
    //             .withArgs(
    //                 requestId,
    //                 ethers.anyValue,
    //                 ethers.anyValue,
    //                 ethers.anyValue
    //             );
    //     });
    // });
}); 