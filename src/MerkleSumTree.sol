// SPDX-License-Identifier: MIT
// Merkle Sum Tree by @high_byte

pragma solidity ^0.8.0;

import "/src/MerkleTree.sol";

contract MerkleSumTree is MerkleTree {
  function _hashLeaf(Item memory item) internal override pure returns (uint256) {
    uint256 hash = uint256(keccak256(abi.encode(item)));
    return (hash << 128) | item.shares;
  }

  function _hashBranch(uint256 hash1, uint256 hash2) internal override pure returns (uint256) {
    uint128 amount1 = uint128(hash1);
    uint128 amount2 = uint128(hash2);
    uint256 hash = MerkleTree._hashBranch(hash1, hash2);
    // AUDIT-NOTE: this will require over 1e20 ethers to overflow.
    return (hash << 128) | (amount1 + amount2);
  }
}
