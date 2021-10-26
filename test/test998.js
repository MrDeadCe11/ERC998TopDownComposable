const { expect, assert } = require("chai");
const { ethers } = require("hardhat");
const {
  isCallTrace,
} = require("hardhat/internal/hardhat-network/stack-traces/message-trace");

describe("Carbon12Portfolio", function () {
  let owner;
  let addr1;
  let addr2;
  let addresses;
  let erc998;
  let carbon12;
  const testUri =
    "ipfs://bafybeihkoviema7g3gxyt6la7vd5ho32ictqbilu3wnlo3rs7ewhnp7lly/";
  let tokenCounter = 0;
  let tokensById = [];
  before(async () => {
    const ERC998TopDownComposableEnumerable = await ethers.getContractFactory(
      "ERC998TopDownComposableEnumerable"
    );
    [owner, addr1, addr2, ...addresses] = await ethers.getSigners();
    erc998 = await ERC998TopDownComposableEnumerable.deploy();
    await erc998.deployed();
  });

  it("should mint a parentNFT and a childNFT to the owner address", async function () {
    //mint parent
    const txp = await erc998
      .mintParent(owner.address, testUri)
      .catch((err) => console.log("PARENT MINT ERROR", err));

    //mint child
    const txc = await erc998
      .mintChild(tokenCounter, testUri)
      .catch((err) => console.log("CHILD MINT ERROR", err));
    const parentId = tokenCounter;
    tokensById.push({ parent0: parentId });
    const promiseP = await txp.wait().then((res) => tokenCounter++);
    const childId = tokenCounter;
    tokensById.push({ child0: childId });
    const promiseC = await txc.wait().then((res) => tokenCounter++);

    const parentOwner = await erc998.ownerOf(parentId);
    const childOwner = await erc998.ownerOf(childId);
    console.log(
      "PARENT OWNER",
      parentOwner,
      "CHILD OWNER",
      childOwner,
      parentId,
      childId
    );
    //promiseP.events[0].args.to;
    assert((parentOwner && childOwner) === owner.address);
  });

  it("should mint a child and parent nft to addr1", async function () {
    //store parentCounter
    const parentId = tokenCounter;
    tokensById.push({ parent1: parentId });
    //mint parent
    const txp = await erc998
      .mintParent(addr1.address, testUri)
      .catch((err) => console.log("PARENT MINT ERROR", err));

    //mint child
    const txc = await erc998
      .mintChild(parentId, testUri)
      .catch((err) => console.log("CHILD MINT ERROR", err));

    const promiseP = await txp.wait().then((res) => tokenCounter++);
    const childId = tokenCounter;
    tokensById.push({ child1: childId });
    const promiseC = await txc.wait().then((res) => tokenCounter++);

    const parentOwner = await erc998.ownerOf(parentId);
    const childOwner = await erc998.ownerOf(childId);
    console.log(
      "PARENT OWNER",
      parentOwner,
      "CHILD OWNER",
      childOwner,
      parentId,
      childId
    );
    //promiseP.events[0].args.to;
    assert((parentOwner && childOwner) === addr1.address);
  });

  it("should return the number nft's owned by an address(owner)", async function () {
    const tx = await erc998.balanceOf(owner.address);

    assert(tx.toNumber() === 2, "address holds incorrect number of tokens");
  });

  it("should return the root owner of owner of child0 (owner account)", async function () {
    const ownerOfParent = await erc998.addressOfRootOwner(erc998.address, 1);
    assert(ownerOfParent === owner.address);
  });

  it("should return the number nft's owned by an address(addr1)", async function () {
    const tx = await erc998.balanceOf(addr1.address);

    assert(tx.toNumber() === 2, "address holds incorrect number of tokens");
  });

  it("should transfer childtoken 0 from owner to parent nft(parent 1) owned by address 1", async function () {
    //approve(current owner address, token to be transfered)
    const approve = await erc998
      .approve(owner.address, 1)
      .catch((err) => console.log("approval error", err));
    //safeTransferFrom(current Owner wallet Address, address of contract that minted ChildNFT, tokenid of ChildNFT, tokenId of ParentNFT)
    const tx = await erc998[`safeTransferFrom(address,address,uint256,bytes)`](
      owner.address,
      erc998.address,
      1,
      2
    ).catch((err) => console.log("add child error", err));

    const promise = await tx.wait();
    const ownerOf1 = await erc998.rootOwnerOf(1);
    const ownerof2 = await erc998.ownerOf(2);
    console.log("ownerOf1", ownerOf1, "ownerof2", ownerof2);
    assert(ownerOf1 === ownerof2, "token not transfered");
  });

  it("owner should only own 1 nft", async function () {
    const tx = await erc998
      .balanceOf(owner.address)
      .catch((err) => console.log(err));
    assert(tx.toNumber() === 2);
  });

  // it("should NOT transfer ownership of childNFT from owner to the ownerNFT", async function () {
  //   const tx = await erc998[
  //     `safeTransferFrom(address,address,uint256,bytes)`
  //   ](owner.address, erc998.address, 1, 0).catch((err) =>
  //     console.log(err)
  //   );
  //   const promise = await tx.wait();
  //   console.log(promise.events[0]);
  //   assert(0 === 0);
  // });
});
