#!/bin/sh

# Build a chain variable, if args contains testnet, chains = arbitrum-sepolia,base-sepolia,optimism-sepolia otherwise, chains = arbitrum,base,optimism,polygon
chains=arbitrum-sepolia,base-sepolia,optimism-sepolia
if [[ $* == *mainnet* ]]; then
  chains=arbitrum,base,optimism,polygon
fi

echo "Deploying contracts to $chains"

# Deploy the contracts
zerodev deploy -f utils/Wrapper.txt -e 0x97A24c95E317c44c0694200dd0415dD6F556663D -s 0x0000000000000000000000000000000000000000000000000000000000000000 -c $chains

# V2 Deployment
zerodev deploy -f v2/MultiSigWebAuthN.txt -e 0xD546c4Ba2e8e5e5c961C36e6Db0460Be03425808 -s 0x0000000000000000000000000000000000000000000000000000000000000000 -c $chains

zerodev deploy -f v2/MultiSigWebAuthNRecovery.txt -e 0x67236B8AAF4B32d2D3269e088B1d43aef7736ab9 -s 0x0000000000000000000000000000000000000000000000000000000000000000 -c $chains

# V3 Deployment
zerodev deploy -f v3/WebAuthNValidator.txt -e 0x2563cEd40Af6f51A3dF0F1b58EF4Cf1B994fDe12 -s 0x0000000000000000000000000000000000000000000000000000000000000000 -c $chains

zerodev deploy -f v3/MultiWebAuthN.txt -e 0x93228CA325349FC7d8C397bECc0515e370aa4555 -s 0x0000000000000000000000000000000000000000000000000000000000000000 -c $chains

zerodev deploy -f v3/NexusFactory.txt -e 0x304bf281a28e451FbCd53FeDb0672b6021E6C40D -s 0x0000000000000000000000000000000000000000000000000000000000000000 -c $chains

zerodev deploy -f v3/RecoverPolicy.txt -e 0xD0b868A455d39be41f6f4bEb1efe3912966e8233 -s 0x0000000000000000000000000000000000000000000000000000000000000000 -c $chains

zerodev deploy -f v3/RecoverAction.txt -e 0x518B5EFB2A2A3c1D408b8aE60A2Ba8D6d264D7BA -s 0x0000000000000000000000000000000000000000000000000000000000000000 -c $chains

