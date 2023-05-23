// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "forge-std/Test.sol";
import "../test/utils/MerkleTestUtils.sol";

// silly test helper since it is using the same contract it is testing...
// even though it accesses the functionality differently to test other functions
// it still requires delicate care

import "../src/MerkleTree.sol";

contract MerkleTests is Test, MerkleTestUtils {
    MerkleTree public merkle;

    constructor() MerkleTestUtils(12, 32) {
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
        console.log("mana (lying forge): %d", g - gasleft());

        _setItem(index, abi.encodePacked(value));
        if (index == $countItems)
            $countItems++;

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

    function updateBatchNodes(uint256[] memory indices, uint256[] memory values) internal {
        uint256 len = indices.length;
        require(len == values.length, "indices and values must be same length");
        uint256[][] memory proofs = new uint256[][](len);
        bytes[] memory params = new bytes[](len);
        uint256[][] memory tree;
        uint256 index;
        for (uint256 i = 0; i < len; i++) {
            index = indices[i];
            uint256 value = values[i];
            // TODO: currently this naive approach allows testing up to height 12~13 or so. upgrade to sparse mpt builder
            tree = merklizeItems();
            proofs[i] = getProof(tree, index);
            params[i] = abi.encodePacked(value);
            _setItem(index, abi.encodePacked(value));
            if (index == $countItems)
                $countItems++;
        }

        uint256 g = gasleft();
        merkle.updateBatchItems(indices, proofs, params);
        console.log("mana batch (lying forge): %d", g - gasleft());

        // re-using proofs[] here, whatever
        index = indices[len - 1];
        tree = merklizeItems();
        proofs[0] = getProof(tree, index);
        // check last proof
        uint256 newRoot = this.calcRoot(proofs[0], tree[0][index]);
        if (newRoot != merkle.$rootHash()) {
            console.log("[root differs] %x != %x", newRoot, merkle.$rootHash());
        }
        require(newRoot == merkle.$rootHash(), "failed to update merkle root properly!");
    }

    function testStressTestTree() public {
        updateNode(0, 1);
        updateNode(1, 2);
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

    
    function testMana() public {
        console.log("insert index 0 (cold)");
        updateNode(0, 1);
        console.log("insert index 1 (warm)");
        updateNode(1, 2);
        console.log("update index 1 (warmer)");
        updateNode(2, 3);

        console.log("repeat - microwave test");
        console.log("insert index 0 (pizza)");
        updateNode(0, 2);
        console.log("insert index 1 (tastes)");
        updateNode(1, 3);
        console.log("update index 1 (microwaved)");
        updateNode(2, 4);
        
    }

    function testManaBatch() public {
        uint256 count = 3;
        uint256[] memory indices = new uint256[](count);
        uint256[] memory values = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            indices[i] = i;
            values[i] = i + 1;
        }

        console.log("1st batch (cold)");
        updateBatchNodes(indices, values);

        console.log("2nd batch (hot)");
        updateBatchNodes(indices, values);
    }
}
