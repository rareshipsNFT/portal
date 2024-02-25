import { expect } from 'chai';
import { BigNumber } from 'ethers';
import { getWallet, deployContract, LOCAL_RICH_WALLETS } from '../deploy/utils';

async function setup() {
    const wallet = getWallet(LOCAL_RICH_WALLETS[0].privateKey);
    const otherWallet = getWallet(LOCAL_RICH_WALLETS[1].privateKey);
    const nftContract = await deployContract("MyNFT", ["Ships", "SHPS", "ipfs://abc/"], { wallet, silent: true });
    const portal = await deployContract("Portal", [], { wallet, silent: true });
    let tx = await nftContract.mint(wallet.address);
    await tx.wait();
    tx = await nftContract.mint(wallet.address);
    await tx.wait();
    tx = await nftContract.setApprovalForAll(portal.address, true);
    await tx.wait();
    tx = await nftContract.mint(otherWallet.address);
    await tx.wait();
    tx = await nftContract.mint(otherWallet.address);
    await tx.wait();
    tx = await nftContract.setApprovalForAll(portal.address, true);
    await tx.wait();
    tx = await nftContract.connect(otherWallet).setApprovalForAll(portal.address, true);
    await tx.wait();
    return { wallet, otherWallet, nftContract, portal };
}


describe('Portal', function () {
    it("Should be possible to deposit nfts and equip them into each other", async function () {
        let { wallet, nftContract, portal } = await setup();

        const tx = await portal.depositNFT(nftContract.address, 1);
        await tx.wait();

        // get list of deposited nfts
        const nfts = await portal.getNFTsByOwner(wallet.address);
        expect(nfts.length).to.equal(1);
        expect(nfts[0].contract_).to.equal(nftContract.address);
        expect(nfts[0].tokenId.toString()).to.equal("1");
    });

    it("Should be possible to withdraw nfts", async function () {
        let { wallet, nftContract, portal } = await setup();

        const tx = await portal.depositNFT(nftContract.address, 1);
        await tx.wait();

        // get list of deposited nfts
        let nfts = await portal.getNFTsByOwner(wallet.address);
        expect(nfts.length).to.equal(1);

        // withdraw nft
        const tx2 = await portal.withdrawNFT(nfts[0].id);
        await tx2.wait();

        // get list of deposited nfts
        nfts = await portal.getNFTsByOwner(wallet.address);
        expect(nfts.length).to.equal(0);

        // check if nft is back in the wallet
        const owner = await nftContract.ownerOf(1);
        expect(owner).to.equal(wallet.address);
    });

    it("Should be possible to equip nfts", async function () {
        let { wallet, nftContract, portal } = await setup();

        let tx = await portal.depositNFT(nftContract.address, 1);
        await tx.wait();
        tx = await portal.depositNFT(nftContract.address, 2);
        await tx.wait();

        // get list of deposited nfts
        let nfts = await portal.getNFTsByOwner(wallet.address);
        expect(nfts.length).to.equal(2);

        // equip nft 0 into nft 1
        const tx2 = await portal.equipNFT(nfts[0].id, nfts[1].id);
        await tx2.wait();

        // get list of equipped nfts for nft 1
        const equippedNfts = await portal.getEquippedNFTs(nfts[1].id);
        expect(equippedNfts.length).to.equal(1);
        expect(equippedNfts[0].contract_).to.equal(nftContract.address);
        expect(equippedNfts[0].tokenId.toString()).to.equal("1");

    });

    it("Should be possible to unequip nfts", async function () {
        let { wallet, nftContract, portal } = await setup();

        let tx = await portal.depositNFT(nftContract.address, 1);
        await tx.wait();
        tx = await portal.depositNFT(nftContract.address, 2);
        await tx.wait();
        let nfts = await portal.getNFTsByOwner(wallet.address);
        tx = await portal.equipNFT(nfts[0].id, nfts[1].id);        
        await tx.wait();

        // unequip nft 0 from nft 1
        const tx2 = await portal.unequipNFT(nfts[0].id, nfts[1].id);
        await tx2.wait();

        // get list of equipped nfts for nft 1
        const equippedNfts = await portal.getEquippedNFTs(nfts[1].id);
        expect(equippedNfts.length).to.equal(0);
    });

    it("Should not be possible to equip nfts that are already equipped", async function () {
        let { wallet, nftContract, portal } = await setup();

        let tx = await portal.depositNFT(nftContract.address, 1);
        await tx.wait();
        tx = await portal.depositNFT(nftContract.address, 2);
        await tx.wait();
        let nfts = await portal.getNFTsByOwner(wallet.address);
        tx = await portal.equipNFT(nfts[0].id, nfts[1].id);        
        await tx.wait();

        // equip nft 0 into nft 1
        let error = false;
        try {
            const tx2 = await portal.equipNFT(nfts[0].id, nfts[1].id);
            await tx2.wait();
        } catch (e) {
            error = true;
        }
        expect(error).to.equal(true);
    });

    it("Should not be possible to unequip nfts that are not equipped", async function () {
        let { wallet, nftContract, portal } = await setup();

        let tx = await portal.depositNFT(nftContract.address, 1);
        await tx.wait();
        tx = await portal.depositNFT(nftContract.address, 2);
        await tx.wait();
        let nfts = await portal.getNFTsByOwner(wallet.address);
        tx = await portal.equipNFT(nfts[0].id, nfts[1].id);        
        await tx.wait();

        // unequip nft 0 from nft 1
        let error = false;
        try {
            const tx2 = await portal.unequipNFT(nfts[1].id, nfts[0].id);
            await tx2.wait();
        } catch (e) {
            error = true;
        }
        expect(error).to.equal(true);
    });

    it("Should be possible to authorize another user to equip nfts", async function () {
        let { wallet, otherWallet, nftContract, portal } = await setup();

        let tx = await portal.depositNFT(nftContract.address, 1);
        await tx.wait();
        tx = await portal.connect(otherWallet).depositNFT(nftContract.address, 3);
        await tx.wait();

        tx = await portal.connect(otherWallet).authorize(wallet.address)
        await tx.wait();

        let myNFTs = await portal.getNFTsByOwner(wallet.address);
        let otherNFTs = await portal.getNFTsByOwner(otherWallet.address);

        tx = await portal.equipNFT(otherNFTs[0].id, myNFTs[0].id);
        await tx.wait();

        let equippedNfts = await portal.getEquippedNFTs(myNFTs[0].id);
        expect(equippedNfts.length).to.equal(1);
        expect(equippedNfts[0].contract_).to.equal(nftContract.address);
        expect(equippedNfts[0].tokenId.toString()).to.equal("3");
        expect(equippedNfts[0].owner).to.equal(otherWallet.address);
    });


});
