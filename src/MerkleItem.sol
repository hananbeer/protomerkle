// SPDX-License-Identifier: MIT
// Merkle Tree Item by @high_byte

pragma solidity ^0.8.0;

struct Item {
  uint128 balance;
  uint128 shares;
  address owner;
}

enum TokenId {
  ETH,
  stETH,
  rETH
}

struct ItemUpdateParams {
  int128 deltaBalance;
  TokenId tokenId;
}
