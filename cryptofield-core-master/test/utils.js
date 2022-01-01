export const funcFromABI = async (abi, funcName) => {
  return abi.find((x) => x.name == funcName);
};

export const signTxData = (signer, data) => {
  return new Promise((resolve, reject) => {
    web3.currentProvider.sendAsync(
      {
        jsonrpc: "2.0",
        id: new Date().getTime(),
        method: "eth_signTypedData",
        params: [signer, data],
      },
      (error, result) => {
        if (error) {
          reject(error);
        } else {
          resolve(result["result"]);
        }
      }
    );
  });
};

export const getTypedData = async (data) => {
  const {
    name,
    version,
    chainId,
    verifyingContract,
    nonce,
    from,
    functionSignature,
  } = data;

  return {
    types: {
      EIP712Domain: [
        {
          name: "name",
          type: "string",
        },
        {
          name: "version",
          type: "string",
        },
        {
          name: "verifyingContract",
          type: "address",
        },
        {
          name: "salt",
          type: "bytes32",
        },
      ],
      MetaTransaction: [
        {
          name: "nonce",
          type: "uint256",
        },
        {
          name: "from",
          type: "address",
        },
        {
          name: "functionSignature",
          type: "bytes",
        },
      ],
    },
    domain: {
      name,
      version,
      verifyingContract,
      salt: "0x" + chainId.toString(16).padStart(64, "0"),
    },
    primaryType: "MetaTransaction",
    message: {
      nonce: parseInt(nonce),
      from,
      functionSignature,
    },
  };
};

export const getRsvFromSig = async (sig) => {
  const signature = sig.substring(2);
  const r = "0x" + signature.substring(0, 64);
  const s = "0x" + signature.substring(64, 128);
  const v = parseInt(signature.substring(128, 130), 16);

  return { r, s, v };
};

export const metaTxsAccounts = [
  {
    balance: 10000000,
    secretKey:
      "0x4f3edf983ac636a65a842ce7c78d9aa706d3b113bce9c46f30d7d21715b23b1d",
  },
  {
    balance: 10000000,
    secretKey:
      "0x6cbed15c793ce57650b9877cf6fa156fbef513c4e6134f022a85b1ffdd59b2a1",
  },
  {
    balance: 10000000,
    secretKey:
      "0x6370fd033278c143179d81c5526140625662b8daa446c22ee2d73db3707e620c",
  },
  {
    balance: 10000000,
    secretKey:
      "0x646f1ce2fdad0e6deeeb5c7e8e5543bdde65e86029e2fd9fc169899c440a7913",
  },
  {
    balance: 10000000,
    secretKey:
      "0xadd53f9a7e588d003326d1cbf9e4a43c061aadd9bc938c843a79e7b4fd2ad743",
  },
];
