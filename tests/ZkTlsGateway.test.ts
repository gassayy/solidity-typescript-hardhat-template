import { expect } from "chai";
import { deployments, ethers, upgrades } from "hardhat";
import { ZkTlsGateway, IERC20, IZkTlsResponseHandler } from "../typechain-types";
import { setupFixture } from "./fixtures/setup"; // Import the setupFixture
import { LogDescription, Signer } from "ethers";

describe("ZkTlsGateway", () => {
  let contracts: any;
  let data: any;
  let functions: any;
  let signers: any;

  before(async () => {
    const fixture = await setupFixture();
    contracts = fixture.contracts;
    data = fixture.data;
    functions = fixture.functions;
    signers = fixture.signers;
  });

  const responseHandlerGasEstimation = async (
    signer: any,
    responseHandler: IZkTlsResponseHandler,
    requestId: string,
    requestHash: string,
    responseBytes: any
  ) => {
    const gasEstimate = await responseHandler.handleResponse.estimateGas(
      requestId,
      requestHash,
      responseBytes
    );
    console.log("estimate gas: ", gasEstimate); // 31518n for none-loop, 4011984n for 10000-iterations
  }

  const computeRequestId = (gatewayAddress: string, accountProxyAddress: string, gatewayNonce: number) => {
    return ethers.keccak256(ethers.solidityPacked(
      ["address", "address", "uint256"], [gatewayAddress, accountProxyAddress, gatewayNonce]
    ));
  }
  const computeRequestHash = (requestId: string, sender: string, encryptedKey: string, nonce: number) => ethers.keccak256(ethers.solidityPacked(
    ["bytes32", "address", "bytes", "uint64"], [requestId, sender, encryptedKey, nonce]
  ));

  describe("Deployment", async () => {
    it("should constracts with correct configuration", async () => {
      const { manager, paymentToken, verifier } = await contracts.zkTlsGateway.getConfiguration();

      expect(manager).to.equal(await contracts.zkTlsManager.getAddress());
      expect(paymentToken).to.equal(await contracts.paymentToken.getAddress());
      expect(verifier).to.equal(await contracts.verifier.getAddress());
    });

  });

  describe("Request TLS Call", () => {
    it("should create a request and emit events", async () => {

      const requestInfo = data.requestInfo;
      const requestBytes = requestInfo.templatedRequest.values.reduce(
        (acc: number, value: any) => acc + value.length, 0
      );
      const estimatedFee = await contracts.zkTlsGateway.estimateFee(
        requestBytes,
        data.feeConfig.maxResponseBytes
      );
      // test fee estimation
      expect(estimatedFee).to.equal(
        (BigInt(requestBytes) + BigInt(data.feeConfig.maxResponseBytes)) * 
        BigInt(data.tokenWeiPerBytes)
      );

      // callback gas estimation
      const nonce = 0;
      const expectedRequestId = computeRequestId(
        await contracts.zkTlsGateway.getAddress(),
        await contracts.accountBeaconProxy.getAddress(),
        nonce
      );
      const expectedRequestHash = computeRequestHash(
        expectedRequestId,
        await signers.applicationUser1.getAddress(),
        data.feeConfig.encryptedKey,
        nonce
      );
      await responseHandlerGasEstimation(
        signers.applicationUser1,
        contracts.responseHandler,
        expectedRequestId,
        expectedRequestHash,
        data.responseBytes
      );
      // test beacon proxy
      const tx = await contracts.accountBeaconProxy
        .connect(signers.applicationUser1).requestTLSCallTemplate(
        requestInfo.remote,
        requestInfo.serverName,
        data.feeConfig.encryptedKey,
        requestInfo.templatedRequest,
        estimatedFee,
        data.feeConfig.maxResponseBytes
      );

      const receipt = await tx.wait();
      const logs = receipt.logs.map((log: any) => contracts.zkTlsGateway.interface.parseLog(log));
      // console.log("logs: ", logs);
      // test logs: RequestTLSCallBegin & RequestTLSCallTemplateField
      logs.forEach((log: any) => {
        log?.name === "RequestTLSCallBegin" &&
          expect(log.args.requestId).to.equal(expectedRequestId) &&
          expect(log.args.requestTemplateHash).to.equal(
            ethers.hexlify(requestInfo.templatedRequest.requestTemplateHash)
          ) &&
          expect(log.args.responseTemplateHash).to.equal(
            ethers.hexlify(requestInfo.templatedRequest.responseTemplateHash)
          ) &&
          expect(log.args.remote).to.equal(requestInfo.remote) &&
          expect(log.args.serverName).to.equal(requestInfo.serverName) &&
          expect(log.args.encryptedKey).to.equal(data.feeConfig.encryptedKey) &&
          expect(log.args.maxResponseBytes).to.equal(data.feeConfig.maxResponseBytes);
      });

    });
  });

  describe("Delivery Response", () => {
      it("should process a response and emit GasUsed", async () => {
         // TODO: test response delivery

      });
  });
}); 