#!/bin/sh

zerodev deploy -f bytecodes/Wrapper.txt -e 0x97A24c95E317c44c0694200dd0415dD6F556663D -s 0x0000000000000000000000000000000000000000000000000000000000000000 -c arbitrum-sepolia,base-sepolia,optimism-sepolia

zerodev deploy -f bytecodes/MultiSigWebAuthNV2.txt -e 0x4De27de97DA4B7d885EED9154bb21510F1329AE1 -s 0x0000000000000000000000000000000000000000000000000000000000000000 -c arbitrum-sepolia,base-sepolia,optimism-sepolia
