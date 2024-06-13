//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// StylusFlattened
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const stylusFlattenedAbi = [
  {
    type: 'function',
    inputs: [],
    name: 'domainSeparator',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'platform_id', internalType: 'bytes32', type: 'bytes32' },
    ],
    name: 'getNonceForPlatform',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'platform_id', internalType: 'bytes32', type: 'bytes32' }],
    name: 'getPlatforOrigin',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'platform_id', internalType: 'bytes32', type: 'bytes32' }],
    name: 'getPlatformMetadata',
    outputs: [
      { name: '', internalType: 'address', type: 'address' },
      { name: '', internalType: 'bytes32', type: 'bytes32' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'platform_id', internalType: 'bytes32', type: 'bytes32' }],
    name: 'getPlatformName',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'owner', internalType: 'address', type: 'address' }],
    name: 'initialize',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'user', internalType: 'address', type: 'address' },
      { name: 'platform_id', internalType: 'bytes32', type: 'bytes32' },
      { name: 'added_consumption', internalType: 'uint256', type: 'uint256' },
      { name: 'deadline', internalType: 'uint256', type: 'uint256' },
      { name: 'v', internalType: 'uint8', type: 'uint8' },
      { name: 'r', internalType: 'bytes32', type: 'bytes32' },
      { name: 's', internalType: 'bytes32', type: 'bytes32' },
    ],
    name: 'pushCcu',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'name', internalType: 'string', type: 'string' },
      { name: 'origin', internalType: 'string', type: 'string' },
      { name: 'owner', internalType: 'address', type: 'address' },
      { name: 'content_type', internalType: 'bytes32', type: 'bytes32' },
      { name: 'deadline', internalType: 'uint256', type: 'uint256' },
      { name: 'v', internalType: 'uint8', type: 'uint8' },
      { name: 'r', internalType: 'bytes32', type: 'bytes32' },
      { name: 's', internalType: 'bytes32', type: 'bytes32' },
    ],
    name: 'registerPlatform',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'platform_id', internalType: 'bytes32', type: 'bytes32' },
      { name: 'name', internalType: 'string', type: 'string' },
      { name: 'owner', internalType: 'address', type: 'address' },
    ],
    name: 'updatePlatformMetadata',
    outputs: [],
    stateMutability: 'nonpayable',
  },
] as const
