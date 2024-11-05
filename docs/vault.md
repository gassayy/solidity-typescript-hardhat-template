# Vault Contract

## Overview

The SubscriberVault contract is a simple contract that allows users to top up their balance of payment token.

Features:
- topUp: 
  - user can top up their balance of payment token by sending configured token to the contract.
  - only configured token is accepted for top-up.
  - mint and transfer the top-up token to user.
- configure: only owner can configure the exchange rate and acceptted token for user top-up.
- balance: user can check their balance of payment token.
- withdraw: 
  - user can withdraw their balance of payment token with equivalent amount of configured token.
  - return convert the remaining balance of payment token to configured token, and send back to user.
  - burn the remaining balance of payment token.
- transfer: user can transfer their balance of payment token to payment receiver address.

