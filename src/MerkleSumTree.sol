// SPDX-License-Identifier: MIT
// Merkle Sum Tree by @high_byte

pragma solidity 0.8.19;

import "./MerkleTree.sol";

contract MerkleSumTree is MerkleTree {
    constructor(uint8 height, uint16 item_size) MerkleTree(height, item_size) {}

    function _getAccumulator(bytes memory item) internal virtual view returns (uint128 accumulator) {
        // override this function.
        // this should look like `return abi.decode(item, Struct).accumulatorField`;
        return abi.decode(item, (uint128));
    }

    function _hashLeaf(
        bytes memory item
    ) internal view override returns (uint256) {
        uint256 hash = uint256(keccak256(abi.encode(item)));
        return (hash << 128) | _getAccumulator(item);
    }

    function _hashBranch(
        uint256 hash1,
        uint256 hash2
    ) internal view override returns (uint256) {
        uint128 amount1 = uint128(hash1);
        uint128 amount2 = uint128(hash2);
        uint256 hash = MerkleTree._hashBranch(hash1, hash2);
        // AUDIT-NOTE: this will require over 1e20 ethers to overflow.
        return (hash << 128) | (amount1 + amount2);
    }
}
