import { expect } from "chai";

import { createInstances, decrypt64 } from "../instance";
import { getSigners, initSigners } from "../signers";
import { deployEncryptedCFMMFixture } from "./CFMM.fixture";

describe("CFMM", function () {
  before(async function () {
    await initSigners();
    this.signers = await getSigners();
  });

  beforeEach(async function () {
    const contract = await deployEncryptedCFMMFixture();
    this.contractAddress = await contract.getAddress();
    this.cfmm = contract;
    this.instances = await createInstances(this.signers);
  });

  it.only("Successfully initialize contract", async function () {
    const addressTokenA = await this.cfmm.TOKEN_A()
    const addressTokenB = await this.cfmm.TOKEN_B()
    expect(addressTokenA).to.equal(process.env.TOKEN_A_LOCAL)
    expect(addressTokenB).to.equal(process.env.TOKEN_B_LOCAL)    
  });
});
