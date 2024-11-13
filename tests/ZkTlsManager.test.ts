import { expect } from "chai"
import { deployments, ethers, upgrades } from "hardhat"
import { ZkTlsManager } from "../typechain-types"
import { setupFixture } from "./fixtures/setup"; // Import the setupFixture

describe("ZkTlsManager", function () {
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

    describe("Deployment", () => {
        it("should set the correct token wei per bytes and owner", async () => {
            // await functions.printContractAddress(contracts);
            // await functions.printSigners(signers); 
            expect(await contracts.zkTlsManager.getAccountBeacon()).to.equal(await contracts.accountBeacon.getAddress());
            expect(await contracts.zkTlsManager.owner()).to.equal(signers.owner.address);
        })

        it("should create a new account", async () => {
            const tx = await contracts.zkTlsManager.createAccount(
                1, contracts.responseHandler2.getAddress()
            );
            const receipt = await tx.wait(); // Wait for the transaction to be mined
            const logs = receipt.logs.map((log: any) => contracts.zkTlsManager.interface.parseLog(log));
            const events = logs.filter((e: any) => e?.name === "SimpleZkTlsAccountCreated");
            // console.info("events: ", events);
            // Check if the event was emitted
            expect(events.length).to.equal(1);
            expect(events[0].args.gatewayId).to.equal(1);
            expect(events[0].args.gateway).to.equal(await contracts.zkTlsGateway.getAddress());
            expect(events[0].args.beaconProxy).not.to.equal(await contracts.accountBeaconProxy.getAddress());

            // console.log("events[0].args.BeaconProxy: ", events[0].args.BeaconProxy);
            // await expect(tx)
            //     .to.emit(contracts.zkTlsManager, 'SimpleZkTlsAccountCreated')
            //     .withArgs(1, await contracts.zkTlsGateway.getAddress(), "0x94099942864EA81cCF197E9D71ac53310b1468D8");

            const versionProxy = await contracts.accountBeaconProxy.VERSION();
            console.log("version: ", versionProxy);

            // check if the proxy is ready to use
            // const beaconProxyAddress = events[0].args.beaconProxy;
            
            // const beaconProxy = new ethers.Contract(beaconProxyAddress, contracts.account.interface, signers.owner);
            
            // // console.log("beaconProxy: ", beaconProxy.interface);
            // const tx1 = await beaconProxy.VERSION;
            // const receipt1 = await tx1.wait();
            // console.log(receipt1);
            // expect(version).to.equal(1);
        })
    })
}) 