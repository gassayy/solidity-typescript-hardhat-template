import { deployments, ethers, upgrades } from "hardhat";
import { IZkTlsResponseHandler } from "../../typechain-types";


const printContractAddress = async (contracts: { [key: string]: any }) => {
  for (const [key, contract] of Object.entries(contracts)) {
    console.log(`${key}: ${await contract.getAddress()}`);
  }
}

const printSigners = async (signers: { [key: string]: any }) => {
  for (const [key, signer] of Object.entries(signers)) {
    console.log(`${key}: ${signer.address}`);
  }
}

export const setupFixture = deployments.createFixture(async () => {
  await deployments.fixture();
  // set up signers
  const [owner, deployer, accountBeaconAdmin, applicationUser1, applicationUser2] = await ethers.getSigners();
  const paymentToken = await ethers.deployContract("BasicERC20", ["Payment Token", "PT", owner.address]);
  const verifier = await ethers.deployContract("MockVerifier");
  const responseHandler = await ethers.deployContract("MockResponseHandler");
  const responseHandler2 = await ethers.deployContract("MockResponseHandler");
  const tokenWeiPerBytes = ethers.parseUnits("1", "gwei");
  // deploy ZkTlsManager
  const ZkTlsManagerFactory = await ethers.getContractFactory("ZkTlsManager");
  const zkTlsManager = await upgrades.deployProxy(
    ZkTlsManagerFactory, [
    await paymentToken.getAddress(),
    accountBeaconAdmin.address,
    owner.address
  ], { initializer: "initialize" }
  );
  await zkTlsManager.waitForDeployment();
  // deploy ZkTlsGateway
  const zkTlsGatewayFactory = await ethers.getContractFactory("ZkTlsGateway");
  const zkTlsGateway = await upgrades.deployProxy(
    zkTlsGatewayFactory, [
    await zkTlsManager.getAddress(),
    BigInt(tokenWeiPerBytes.toString()),
    await paymentToken.getAddress(),
    await verifier.getAddress(),
    owner.address
  ]);
  await zkTlsGateway.waitForDeployment();

  // Deploy the implementation contract
  const accountContract = await ethers.getContractFactory("SimpleZkTlsAccount");
  const accountBeacon = await upgrades.deployBeacon(accountContract);
  await accountBeacon.waitForDeployment();
  console.log("accountBeacon deployed to:", await accountBeacon.getAddress());
  // Deploy the beacon with the implementation address
  const accountBeaconProxy = await upgrades.deployBeaconProxy(
    await accountBeacon.getAddress(),
    accountContract,
    [
      await zkTlsGateway.getAddress(),
      await paymentToken.getAddress(),
      await responseHandler.getAddress()
    ]
  );
  await accountBeaconProxy.waitForDeployment();
  console.log("Beacon Proxy deployed to:", await accountBeaconProxy.getAddress());
  // set beacon to zkTlsManager
  await zkTlsManager.setAccountBeacon(await accountBeacon.getAddress());
  await zkTlsManager.setGateway(1, await zkTlsGateway.getAddress());
  await zkTlsManager.authorizeAccount(await accountBeaconProxy.getAddress(), await zkTlsGateway.getAddress());
  // request info and data
  const requestInfo = {
    remote: "https://httpbin.org",
    serverName: "httpbin.org",
    templatedRequest: {
      requestTemplateHash: ethers.randomBytes(32),
      responseTemplateHash: ethers.randomBytes(32),
      fields: [1 ,2 , 3],
      values: [ethers.randomBytes(32), ethers.randomBytes(32), ethers.randomBytes(32)],
    },
    data: [ethers.randomBytes(32), ethers.randomBytes(32), ethers.randomBytes(32)],
  };
  const feeConfig = {
    fee: ethers.parseEther("4"),
    maxResponseBytes: 1024n * 10n, // 10KB
    encryptedKey: ethers.ZeroHash,
  };

  const responseBytes = ethers.randomBytes(256);

  const genRequestId = (gatewayAddress: string, accountAddress: string, gatewayNonce: number) => {
    return ethers.keccak256(ethers.solidityPacked(
      ["address", "address", "uint256"], [gatewayAddress, accountAddress, gatewayNonce]
    ));
  };

  return {
    contracts: {
      zkTlsGateway,
      zkTlsManager,
      accountBeacon,
      accountBeaconProxy,
      paymentToken,
      verifier,
      responseHandler,
      responseHandler2
    },
    data: {
      requestInfo,
      feeConfig,
      tokenWeiPerBytes,
      responseBytes,
    },
    functions: {
      genRequestId,
      printContractAddress,
      printSigners,
    },
    signers: {
      owner,
      deployer,
      accountBeaconAdmin,
      applicationUser1,
      applicationUser2
    }
  };
});
