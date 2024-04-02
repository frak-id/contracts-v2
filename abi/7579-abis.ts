//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// WebAuthNValidator
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const webAuthNValidatorAbi = [
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
        name: 'b64AuthenticatorId',
        internalType: 'string',
        type: 'string',
        indexed: true,
      },
      { name: 'x', internalType: 'uint256', type: 'uint256', indexed: false },
      { name: 'y', internalType: 'uint256', type: 'uint256', indexed: false },
    ],
    name: 'WebAuthnPublicKeyChanged',
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
] as const
