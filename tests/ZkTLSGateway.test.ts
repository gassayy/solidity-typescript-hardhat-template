import { expect } from "chai";
import { ZkTlsGateway, IERC20 } from "../typechain-types";
import { setupFixture } from "./fixtures/setup"; // Import the setupFixture

describe("ZkTlsGateway", () => {
  let contracts: any;
  let data: any;
  let functions: any;

  before(async () => {
    console.log(" --------------- before -------------");
    const fixture = await setupFixture();
    contracts = fixture.contracts;
    data = fixture.data;
    functions = fixture.functions;
  });

  describe("Deployment", async() => {
    it("should constracts with correct configuration", async () => {
      const { manager, paymentToken, verifier } = await contracts.zkTlsGateway.getConfiguration();

      expect(manager).to.equal(await contracts.zkTlsManager.getAddress());
      expect(paymentToken).to.equal(await contracts.paymentToken.getAddress());
      expect(verifier).to.equal(await contracts.verifier.getAddress()); 
    });

    it("should configure ZkTls manager", async () => {
      await contracts.zkTlsManager.setAccountToGateway(
        await contracts.account.getAddress(),
        await contracts.zkTlsGateway.getAddress()
      );
      expect(await contracts.zkTlsManager.checkAccess(
        await contracts.account.getAddress(),
        await contracts.zkTlsGateway.getAddress()
      )).to.be.true;
      expect(await contracts.zkTlsManager.getTokenWeiPerBytes()).to.equal(data.tokenWeiPerBytes);
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