// SPDX-License-Identifier: MIT
// Merkle Tree by @high_byte

pragma solidity ^0.8.0;

import "./MerkleItem.sol";

contract MerkleTree {
  // TODO: immutable at constructor?
  uint256 constant public TREE_HEIGHT = 4;
  uint256 constant public MAX_NODES = 1 << TREE_HEIGHT;
  uint256 immutable public EMPTY_LEAF;

  uint256 public $rootHash;
  uint256 public $countItems;
  mapping(uint256 index => Item item) public $items;

  constructor() {
    uint256 hash = _hashEmptyLeaf();
    EMPTY_LEAF = hash;
    for (uint256 i = 0; i < TREE_HEIGHT; i++) {
      hash = _hashBranch(hash, hash);
    }

    unchecked { $rootHash = hash; }
  }

  function _hashLeaf(Item memory item) internal virtual pure returns (uint256 hash) {
    hash = uint256(keccak256(abi.encode(item)));
  }

  function _hashEmptyLeaf() internal virtual pure returns (uint256 hash) {
    Item memory item;
    hash = _hashLeaf(item);
  }

  function _hashBranch(uint256 hash1, uint256 hash2) internal virtual pure returns (uint256 hash) {
    if (hash1 > hash2) {
        hash = uint256(keccak256(abi.encode(hash1, hash2)));
    } else {
        hash = uint256(keccak256(abi.encode(hash2, hash1)));
    }
  }

  /*
    does not do range checks
    AUDIT-NOTE: empty proof will simply return _leaf
  */
  // TODO: move _proof to calldata
  function _calcRoot(uint256[] calldata _proof, uint256 _leaf) internal pure returns (uint256) {
    uint256 proofElement;
    uint256 computedHash = _leaf;

    for (uint256 i = 0; i < _proof.length; i++) {
      // avoid array dereference bound check
      unchecked { proofElement = _proof[i]; }
      computedHash = _hashBranch(computedHash, proofElement);
    }

    return computedHash;
  }

  function update(
    uint256 index,
    ItemUpdateParams memory params,
    uint256[] calldata _depositProof
  ) public payable {
    require(_depositProof.length == TREE_HEIGHT, "proofs length must be TREE_HEIGHT");
    
    uint256 lastIndex = $countItems;
    require(index <= lastIndex, "index out of bounds");
    require(index < MAX_NODES, "tree is full");

    Item memory item = $items[index];

    // pre-update root verification
    uint256 oldLeaf = _hashLeaf(item);
    uint256 preUpdateHash = _calcRoot(_depositProof, oldLeaf);
    require(preUpdateHash == $rootHash, "invalid pre-update root");

    // update item in-memory
    _onBeforeUpdate(item, params);

    // post-update root calculation
    uint256 newLeaf = _hashLeaf(item);
    $rootHash = _calcRoot(_depositProof, newLeaf);

    // apply updates to storage
    if (index == lastIndex) {
      $countItems++;
    }
    $items[index] = item;

    // call post-update hooks
    _onAfterUpdate(item, params);
  }

  function _onBeforeUpdate(Item memory item, ItemUpdateParams memory params) internal view virtual returns (Item memory) {
    revert("must implement _onBeforeUpdate");
  }

  function _onAfterUpdate(Item memory item, ItemUpdateParams memory params) internal virtual {
  }
}