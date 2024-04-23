//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// MultiWebAuthNValidatorV3
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const multiWebAuthNValidatorV3Abi = [
  {
    type: 'constructor',
    inputs: [
      { name: '_p256Verifier', internalType: 'address', type: 'address' },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'authenticatorId', internalType: 'bytes32', type: 'bytes32' },
      { name: 'x', internalType: 'uint256', type: 'uint256' },
      { name: 'y', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'addPassKey',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: '_smartWallet', internalType: 'address', type: 'address' },
    ],
    name: 'getPasskey',
    outputs: [
      { name: '', internalType: 'bytes32', type: 'bytes32' },
      {
        name: '',
        internalType: 'struct WebAuthNPubKey',
        type: 'tuple',
        components: [
          { name: 'x', internalType: 'uint256', type: 'uint256' },
          { name: 'y', internalType: 'uint256', type: 'uint256' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '_smartWallet', internalType: 'address', type: 'address' },
      { name: '_authenticatorId', internalType: 'bytes32', type: 'bytes32' },
    ],
    name: 'getPasskey',
    outputs: [
      { name: '', internalType: 'bytes32', type: 'bytes32' },
      {
        name: '',
        internalType: 'struct WebAuthNPubKey',
        type: 'tuple',
        components: [
          { name: 'x', internalType: 'uint256', type: 'uint256' },
          { name: 'y', internalType: 'uint256', type: 'uint256' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'smartAccount', internalType: 'address', type: 'address' },
    ],
    name: 'isInitialized',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'typeID', internalType: 'uint256', type: 'uint256' }],
    name: 'isModuleType',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'pure',
  },
  {
    type: 'function',
    inputs: [
      { name: '_sender', internalType: 'address', type: 'address' },
      { name: '_hash', internalType: 'bytes32', type: 'bytes32' },
      { name: '_data', internalType: 'bytes', type: 'bytes' },
    ],
    name: 'isValidSignatureWithSender',
    outputs: [{ name: '', internalType: 'bytes4', type: 'bytes4' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '_data', internalType: 'bytes', type: 'bytes' }],
    name: 'onInstall',
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'bytes', type: 'bytes' }],
    name: 'onUninstall',
    outputs: [],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'authenticatorId', internalType: 'bytes32', type: 'bytes32' },
    ],
    name: 'removePassKey',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'authenticatorId', internalType: 'bytes32', type: 'bytes32' },
    ],
    name: 'setPrimaryPassKey',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_userOp',
        internalType: 'struct PackedUserOperation',
        type: 'tuple',
        components: [
          { name: 'sender', internalType: 'address', type: 'address' },
          { name: 'nonce', internalType: 'uint256', type: 'uint256' },
          { name: 'initCode', internalType: 'bytes', type: 'bytes' },
          { name: 'callData', internalType: 'bytes', type: 'bytes' },
          {
            name: 'accountGasLimits',
            internalType: 'bytes32',
            type: 'bytes32',
          },
          {
            name: 'preVerificationGas',
            internalType: 'uint256',
            type: 'uint256',
          },
          { name: 'gasFees', internalType: 'bytes32', type: 'bytes32' },
          { name: 'paymasterAndData', internalType: 'bytes', type: 'bytes' },
          { name: 'signature', internalType: 'bytes', type: 'bytes' },
        ],
      },
      { name: '_userOpHash', internalType: 'bytes32', type: 'bytes32' },
    ],
    name: 'validateUserOp',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'payable',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'smartAccount',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'authenticatorIdHash',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true,
      },
    ],
    name: 'PrimaryPassKeyChanged',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'smartAccount',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'authenticatorIdHash',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true,
      },
      { name: 'x', internalType: 'uint256', type: 'uint256', indexed: false },
      { name: 'y', internalType: 'uint256', type: 'uint256', indexed: false },
    ],
    name: 'WebAuthnPublicKeyAdded',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'smartAccount',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'authenticatorIdHash',
        internalType: 'bytes32',
        type: 'bytes32',
        indexed: true,
      },
    ],
    name: 'WebAuthnPublicKeyRemoved',
  },
  {
    type: 'error',
    inputs: [
      { name: 'smartAccount', internalType: 'address', type: 'address' },
    ],
    name: 'AlreadyInitialized',
  },
  {
    type: 'error',
    inputs: [
      { name: 'smartAccount', internalType: 'address', type: 'address' },
      { name: 'authenticatorIdHash', internalType: 'bytes32', type: 'bytes32' },
    ],
    name: 'CantRemoveMainPasskey',
  },
  {
    type: 'error',
    inputs: [
      { name: 'x', internalType: 'uint256', type: 'uint256' },
      { name: 'y', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'InvalidInitData',
  },
  {
    type: 'error',
    inputs: [{ name: 'target', internalType: 'address', type: 'address' }],
    name: 'InvalidTargetAddress',
  },
  { type: 'error', inputs: [], name: 'InvalidWebAuthNData' },
  {
    type: 'error',
    inputs: [
      { name: 'smartAccount', internalType: 'address', type: 'address' },
    ],
    name: 'NotInitialized',
  },
  {
    type: 'error',
    inputs: [
      { name: 'smartAccount', internalType: 'address', type: 'address' },
      { name: 'authenticatorIdHash', internalType: 'bytes32', type: 'bytes32' },
    ],
    name: 'PassKeyAlreadyExist',
  },
  {
    type: 'error',
    inputs: [
      { name: 'smartAccount', internalType: 'address', type: 'address' },
      { name: 'authenticatorIdHash', internalType: 'bytes32', type: 'bytes32' },
    ],
    name: 'PassKeyDontExist',
  },
] as const
