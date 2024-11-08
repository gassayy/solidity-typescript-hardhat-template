import { expect } from "chai";
import { deployments, ethers } from "hardhat";
import { AbiCoder, Signature, concat, getBytes, hashMessage, keccak256, Signer } from "ethers";

interface ForwardRequest {
    from: string;
    to: string;
    value: bigint;
    gas: bigint;
    nonce: bigint;
    data: string;
}

describe("ForwardingContract", () => {
    const setupFixture = deployments.createFixture(async () => {
        await deployments.fixture();

        const forwardingContract = await ethers.deployContract("Forwarding");
        const targetContract = await ethers.deployContract("TargetContract");

        const [owner, user] = await ethers.getSigners();


        console.log("forwardingContractAddress", await forwardingContract.getAddress());
        console.log("targetContractAddress", await targetContract.getAddress());

        return {
            forwardingContract,
            targetContract,
            owner,
            user,
            forwardingContractAddress: await forwardingContract.getAddress(),
            targetContractAddress: await targetContract.getAddress(),
        };
    });

    async function createForwardRequest(
        from: string,
        to: string,
        value: bigint,
        gas: bigint,
        nonce: bigint,
        data: string
    ) {
        return {
            from,
            to,
            value,
            gas,
            nonce,
            data,
        };
    }

    async function createSignature(request: ForwardRequest, signer: Signer) {
        const encodedData = AbiCoder.defaultAbiCoder().encode(
            ['address', 'address', 'uint256', 'uint256', 'uint256', 'bytes'],
            [request.from, request.to, request.value, request.gas, request.nonce, request.data]
        );
        const hashedData = keccak256(encodedData);
        const messageHashBytes = getBytes(hashedData);
        const prefixedHash = hashMessage(messageHashBytes);
        const signature = await signer.signMessage(messageHashBytes);
        const sig = Signature.from(signature);
        const formattedSignature = concat([
            new Uint8Array([sig.v]),
            sig.r,
            sig.s,
        ]);
        
        return formattedSignature;
    }

    describe("Forwarding", () => {
        it("should verify signature", async () => {
            const { forwardingContract, targetContract, user } = await setupFixture();
            
            const request = {
                from: await user.getAddress(),
                to: await targetContract.getAddress(),
                value: 0n,
                gas: 100000n,
                nonce: 0n,
                data: targetContract.interface.encodeFunctionData("setValue", [42n])
            };

            const signature = await createSignature(request, user);
            const isValid = await forwardingContract.verify(request, signature);
            expect(isValid).to.be.true;
        });

        it.only("should forward a transaction and update target contract state", async () => {
            const { forwardingContract, targetContract, user } = await setupFixture();

            console.log("userAddress", await user.getAddress());
            const userAddress = await user.getAddress();
            const setValue = targetContract.interface.encodeFunctionData("setValue", [42n]);
            
            const request = await createForwardRequest(
                await user.getAddress(),
                await targetContract.getAddress(),
                0n, // value
                100000n, // gas
                0n, // nonce
                setValue
            );
            const signature = await createSignature(request, user);
            await forwardingContract.execute(request, signature);

            const value = await targetContract.getValue(await forwardingContract.getAddress());
            expect(value).to.equal(42n);
        });

        it.skip("should fail with invalid nonce", async () => {
            const { forwardingContract, targetContract, user } = await setupFixture();

            const setValue = targetContract.interface.encodeFunctionData("setValue", [42n]);
            
            const request = await createForwardRequest(
                await user.getAddress(),
                await targetContract.getAddress(),
                0n,
                100000n,
                1n, // Wrong nonce
                setValue
            );
            const signature = await createSignature(request, user);
            await expect(forwardingContract.execute(request, signature))
                .to.be.revertedWithCustomError(forwardingContract, "InvalidNonce");
        });
       
    });
});

describe("TargetContract", () => {
    const setupFixture = deployments.createFixture(async () => {
        await deployments.fixture();

        const targetContract = await ethers.deployContract("TargetContract");
        const [owner, user] = await ethers.getSigners();

        return {
            targetContract,
            targetContractAddress: await targetContract.getAddress(),
            owner,
            user,
        };
    });

    describe("Direct Interactions", () => {
        it("should set and get values correctly", async () => {
            const { targetContract, user } = await setupFixture();

            await targetContract.connect(user).setValue(123n);
            expect(await targetContract.getValue(await user.getAddress())).to.equal(123n);
        });

        it("should store values separately for different users", async () => {
            const { targetContract, owner, user } = await setupFixture();

            await targetContract.connect(owner).setValue(100n);
            await targetContract.connect(user).setValue(200n);

            expect(await targetContract.getValue(await owner.getAddress())).to.equal(100n);
            expect(await targetContract.getValue(await user.getAddress())).to.equal(200n);
        });
    });
}); 