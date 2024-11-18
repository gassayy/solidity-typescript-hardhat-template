#!/bin/bash

OWNER_ADDRESS=<owner_address>
OWNER_PRIVATE_KEY=0x0
RPC_URL=<custom.public_rpc_url>
ACCOUNT_BEACON=0x6cb4185c3D8723252650Ce2Cb6b539c5B8c649f3
ACCOUNT_BEACON_PROXY=0x8622F295950BB1F09e8984B6e9193AF96cE837dA
ZKTLS_MANAGER_ADDRESS=0x894Bf834bc32c9c3c02c99b372283383a2C28f1F
PAYMENT_TOKEN=0xc7A26aa53B2EBe73F713FD33Eb9c3EF94560C05b

# Mint 1,000,000 tokens to the account
cast send \
  --rpc-url $RPC_URL \
  --private-key $OWNER_PRIVATE_KEY \
  $PAYMENT_TOKEN \
  "mint(address,uint256)" \
  $ACCOUNT_BEACON_PROXY \
  1000000000000000000000000 \
  --from $OWNER_ADDRESS

# Send 0.01 ETH to the account
cast send \
  --rpc-url $RPC_URL \
  --private-key $OWNER_PRIVATE_KEY \
  $ACCOUNT_BEACON_PROXY \
  --value 10000000000000000 \
  --from $OWNER_ADDRESS

# Get ETH balance of the account
cast balance $ACCOUNT_BEACON_PROXY --rpc-url $RPC_URL

# Get token balance of the account
cast call $PAYMENT_TOKEN "balanceOf(address)" $ACCOUNT_BEACON_PROXY --rpc-url $RPC_URL
