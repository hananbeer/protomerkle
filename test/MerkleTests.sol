// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../test/utils/MerkleTestUtils.sol";

// silly test helper since it is using the same contract it is testing...
// even though it accesses the functionality differently to test other functions
// it still requires delicate care

import "../src/MerkleTree.sol";

contract MerkleTests is Test, MerkleTestUtils {
    MerkleTree public merkle;

    constructor() MerkleTestUtils(2, 32) {
    }

    function setUp() public {
        merkle = new MerkleTree(uint8(TREE_HEIGHT), uint16(ITEM_SIZE));
    }

    function clamp(int128 n) internal pure returns (uint128) {
        if (n < 0)
            return 0;

        return uint128(n);
    }

    function deadAddr(uint256 index) internal pure returns (address) {
        return address(uint160((0xdead << 144) | index));
    }

    function updateNode(uint256 index, uint256 value) internal {
        uint256[][] memory tree = merklizeItems();
        uint256[] memory proof = getProof(tree, index);
        
        // uint256 currentRoot = this.calcRoot(proof, tree[0][index]);
        // console.log("currentRoot: %x, contract's root: %x", currentRoot, merkle.$rootHash());

        uint256 g = gasleft();
        merkle.updateItem(index, proof, abi.encodePacked(value));
        console.log("mana: %d", g - gasleft());

        _setItem(index, abi.encodePacked(value));

        tree = merklizeItems();
        proof = getProof(tree, index);
        uint256 newRoot = this.calcRoot(proof, tree[0][index]);

        if (newRoot != merkle.$rootHash()) {
            console.log("[root differs] %x != %x", newRoot, merkle.$rootHash());
        }
        require(
            newRoot == merkle.$rootHash(),
            "failed to update merkle root properly!"
        );
    }

    function testStressTestTree() public {
        uint256 len = MAX_NODES;
        console.log("insert index 0 (cold)");
        updateNode(0, 1);
        console.log("insert index 1 (warm)");
        updateNode(1, 2);
        console.log("update index 1 (warmer)");
        updateNode(1, 3);
        for (uint128 i = 2; i < MAX_NODES; i++) {
            updateNode(i, 0x100 + i);
            for (uint128 j = i; j > 0; j--) {
                updateNode(j - 1, 0x1000 + i + j);
            }
            updateNode(i - 1, 0x10);
        }
        updateNode(0, 5);
        updateNode(1, 6);
        updateNode(0, 7);
        updateNode(1, 8);
    }
}
