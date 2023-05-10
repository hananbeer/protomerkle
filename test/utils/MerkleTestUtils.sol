// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../src/MerkleTree.sol";

abstract contract MerkleTestUtils is MerkleTree {
    constructor(uint8 height, uint16 item_size) MerkleTree(height, item_size) {
    }

    function getProof(
        uint256[][] memory tree,
        uint256 index
    ) internal pure returns (uint256[] memory proof) {
        require(index >= 0 && index < tree[0].length, "[gp] index out of bounds");

        proof = new uint256[](tree.length - 1);
        for (uint256 level = 0; level < tree.length - 1; level++) {
            uint256 proof_item = tree[level][index ^ 1];
            proof[level] = proof_item;
            index >>= 1;
        }
    }

    function getEmptyNode(uint256 idx) internal view returns (uint256 hash) {
        require(idx < TREE_HEIGHT, "[gen] index out of bounds");
        hash = EMPTY_LEAF;
        for (uint256 i = 0; i <= idx; i++)
            hash = _hashBranch(hash, hash);
    }

    function getItem(
        uint256[] memory items,
        uint256 index,
        uint256 max_len,
        uint256 defaultVal
    ) internal pure returns (uint256) {
        if (index < max_len)
            return items[index];

        return defaultVal;
    }

    function itemsToHashes() internal view returns (uint256[] memory hashes) {
        uint256 len = 1 << TREE_HEIGHT;
        hashes = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            hashes[i] = _hashLeaf(_getItem(i));
        }
    }

    function merklizeItems() internal view returns (uint256[][] memory buckets) {
        uint256[] memory hashes = itemsToHashes();

        // max 2**height elements
        uint256 len = 1 << TREE_HEIGHT;
        uint256[] memory bucket_hashes = new uint256[](len);
        uint256 defaultVal = EMPTY_LEAF;
        for (uint256 i = 0; i < len; i++) {
            bucket_hashes[i] = getItem(hashes, i, hashes.length, defaultVal);
        }

        buckets = new uint256[][](TREE_HEIGHT + 1);
        buckets[0] = bucket_hashes;
        for (uint256 level = 1; level <= TREE_HEIGHT; level++) {
            defaultVal = getEmptyNode(level - 1);
            bucket_hashes = new uint256[](len);
            for (uint256 i = 0; i < len; i++) {
                uint256 minLen = (hashes.length >= len ? len : hashes.length);
                uint256 item1 = getItem(hashes, 2 * i, minLen, defaultVal);
                uint256 item2 = getItem(hashes, 2 * i + 1, minLen, defaultVal);
                hashes[i] = _hashBranch(item1, item2); bucket_hashes[i] = hashes[i];
            }
            buckets[level] = bucket_hashes;
            len >>= 1;
        }
    }

    function calcRoot(uint256[] calldata _proof, uint256 _leaf) public view returns (uint256) {
        return _calcRoot(_proof, _leaf);
    }
}
