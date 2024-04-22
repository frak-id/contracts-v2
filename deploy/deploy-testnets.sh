#!/bin/sh

zerodev deploy -f bytecodes/Wrapper.txt -e 0x97A24c95E317c44c0694200dd0415dD6F556663D -s 0x0000000000000000000000000000000000000000000000000000000000000000 -c arbitrum-sepolia,base-sepolia,optimism-sepolia

zerodev deploy -f bytecodes/MultiSigWebAuthNV2.txt -e 0xD546c4Ba2e8e5e5c961C36e6Db0460Be03425808 -s 0x0000000000000000000000000000000000000000000000000000000000000000 -c arbitrum-sepolia,base-sepolia,optimism-sepolia

zerodev deploy -f bytecodes/MultiSigWebAuthNRecoveryV2.txt -e 0x67236B8AAF4B32d2D3269e088B1d43aef7736ab9 -s 0x0000000000000000000000000000000000000000000000000000000000000000 -c arbitrum-sepolia,base-sepolia,optimism-sepolia
