const { ethers, network } = require("hardhat");
const { expect } = require("chai");

const totalToken = "1000000000000000000"; // 10

describe("BlockzGovernanceToken", function () {
  before(async function () {
    // ABIs
    this.blockzGovernanceTokenCF = await ethers.getContractFactory(
      "BlockzGovernanceToken"
    );

    // Accounts
    this.signers = await ethers.getSigners();
    this.owner = this.signers[0];
  });
  beforeEach(async function () {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: "https://api.avax.network/ext/bc/C/rpc",
            blockNumber: 6413723,
          },
          live: false,
          saveDeployments: true,
          tags: ["test", "local"],
        },
      ],
    });
    // Contracts
    this.blockzGovernanceToken = await this.blockzGovernanceTokenCF.deploy(
      "Test Rock",
      "TROCK"
    );
  });

  it("initial mint", async function () {
    await expect(
      this.blockzGovernanceToken.initialMint([this.signers[1].address], [])
    ).to.be.revertedWith("Receivers-Values mismatch");
    await expect(
      this.blockzGovernanceToken
        .connect(this.signers[1])
        .initialMint([this.signers[1].address], [])
    ).to.be.revertedWith("Ownable: caller is not the owner");
    await expect(
      this.blockzGovernanceToken.initialMint(
        [this.signers[1].address],
        [totalToken]
      )
    ).to.emit(this.blockzGovernanceToken, "BlockzTokenMinted");
    await expect(
      this.blockzGovernanceToken.initialMint(
        [this.signers[1].address],
        [totalToken]
      )
    ).to.be.revertedWith("Tokens have already been minted");
  });

  it("snapshot", async function () {
    await expect(
      this.blockzGovernanceToken.connect(this.signers[1]).snapshot()
    ).to.be.revertedWith("Ownable: caller is not the owner");
    await expect(this.blockzGovernanceToken.snapshot())
      .to.emit(this.blockzGovernanceToken, "Snapshot")
      .withArgs(1);
  });
});
