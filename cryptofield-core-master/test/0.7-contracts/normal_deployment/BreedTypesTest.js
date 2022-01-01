const BreedTypes = artifacts.require("BreedTypes");

const genesis =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const legendary = web3.utils.toHex("legendary");
const exclusive = web3.utils.toHex("exclusive");
const elite = web3.utils.toHex("elite");
const cross = web3.utils.toHex("cross");
const pacer = web3.utils.toHex("pacer");

contract("BreedTypes", (acc) => {
  let breedTypes;

  beforeEach("setup instances", async () => {
    breedTypes = await BreedTypes.new();

    await breedTypes.grantRole(web3.utils.toHex("breed_types_owners"), acc[0]);
  });

  describe("constructor", async () => {
    describe("_populateMatrix", async () => {
      it("populates genesis matrix", async () => {
        await compareBreedTypes(genesis, genesis, "legendary");
        await compareBreedTypes(genesis, legendary, "exclusive");
        await compareBreedTypes(genesis, exclusive, "exclusive");
        await compareBreedTypes(genesis, elite, "elite");
        await compareBreedTypes(genesis, cross, "cross");
        await compareBreedTypes(genesis, pacer, "pacer");
      });

      it("populates legendary matrix", async () => {
        await compareBreedTypes(legendary, genesis, "exclusive");
        await compareBreedTypes(legendary, legendary, "exclusive");
        await compareBreedTypes(legendary, exclusive, "elite");
        await compareBreedTypes(legendary, elite, "cross");
        await compareBreedTypes(legendary, cross, "cross");
        await compareBreedTypes(legendary, pacer, "pacer");
      });

      it("populates exclusive matrix", async () => {
        await compareBreedTypes(exclusive, genesis, "elite");
        await compareBreedTypes(exclusive, legendary, "elite");
        await compareBreedTypes(exclusive, exclusive, "elite");
        await compareBreedTypes(exclusive, elite, "cross");
        await compareBreedTypes(exclusive, cross, "cross");
        await compareBreedTypes(exclusive, pacer, "pacer");
      });

      it("populates elite matrix", async () => {
        await compareBreedTypes(elite, genesis, "cross");
        await compareBreedTypes(elite, legendary, "cross");
        await compareBreedTypes(elite, exclusive, "cross");
        await compareBreedTypes(elite, elite, "cross");
        await compareBreedTypes(elite, cross, "cross");
        await compareBreedTypes(elite, pacer, "pacer");
      });

      it("populates cross matrix", async () => {
        await compareBreedTypes(cross, genesis, "cross");
        await compareBreedTypes(cross, legendary, "cross");
        await compareBreedTypes(cross, exclusive, "cross");
        await compareBreedTypes(cross, elite, "cross");
        await compareBreedTypes(cross, cross, "pacer");
        await compareBreedTypes(cross, pacer, "pacer");
      });

      it("populates pacer matrix", async () => {
        await compareBreedTypes(pacer, genesis, "pacer");
        await compareBreedTypes(pacer, legendary, "pacer");
        await compareBreedTypes(pacer, exclusive, "pacer");
        await compareBreedTypes(pacer, elite, "pacer");
        await compareBreedTypes(pacer, cross, "pacer");
        await compareBreedTypes(pacer, pacer, "pacer");
      });

      const compareBreedTypes = async (firstType, secondType, expectedType) => {
        let contractType = await breedTypes.getBreedTypeFromMatrix(
          firstType,
          secondType
        );

        assert.equal(web3.utils.toUtf8(contractType), expectedType);
      };
    });
  });

  describe("setBreedType", async () => {
    it("sets the breed type for a horse id", async () => {
      await breedTypes.setBreedType(100, web3.utils.toHex("legendary"));

      let contractType = await breedTypes.getBreedType(100);

      assert.equal(web3.utils.toUtf8(contractType), "legendary");
    });
  });

  describe("generateBreedType", async () => {
    it("generates breed type of horse based in parents", async () => {
      await breedTypes.setBreedType(100, web3.utils.toHex("cross"));
      await breedTypes.setBreedType(101, web3.utils.toHex("legendary"));

      await breedTypes.generateBreedType(131, 100, 101);

      let offspringType = await breedTypes.getBreedType(131);

      assert.equal(web3.utils.toUtf8(offspringType), "cross");
    });
  });
});
