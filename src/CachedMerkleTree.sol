// SPDX-License-Identifier: MIT
// Summerkle Tree

pragma solidity ^0.8.0;

import "forge-std/console.sol";

contract CachedMerkleTree {
    bool public debug = false;

    function setDebug(bool _debug) external {
        debug = _debug;
    }

    uint256 public immutable TREE_HEIGHT;
    uint256 public immutable MAX_NODES;
    uint256 public immutable EMPTY_LEAF;
    uint256 public immutable ITEM_SIZE;

    uint256 public $rootHash;
    uint256 public $countItems;
    mapping(uint256 /*index*/ => uint256 /*ptr_base*/) public $items;
    mapping(uint256 => uint256) public $rmln;
    mapping(uint256 => uint256) public $zeros;

    constructor(uint8 height, uint16 item_size) {
        require(item_size > 0, "item size must be greater than zero");
        require(height > 1, "height must be greater than one");
        TREE_HEIGHT = height;
        MAX_NODES = 1 << height;
        ITEM_SIZE = item_size;

        bytes memory raw_empty_bytes = new bytes(item_size);
        uint256 hash = _hashLeaf(abi.encodePacked(raw_empty_bytes));
        EMPTY_LEAF = hash;
        for (uint256 i = 0; i < height; i++) {
            $rmln[i] = hash;
            $zeros[i] = hash;
            // console.log("zeros[%d] = %x", i, hash);
            hash = _hashBranch(hash, hash);
        }

        $rootHash = hash;
    }

    // ====================== \\
    // ====== INTERNAL ====== \\
    // ====================== \\

    function _hashLeaf(
        bytes memory raw_bytes
    ) internal pure virtual returns (uint256 hash) {
        hash = uint256(keccak256(raw_bytes));
    }

    function _hashBranch(
        uint256 hash1,
        uint256 hash2
    ) internal pure virtual returns (uint256 hash) {
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
    function _calcRoot(
        uint256[] memory _proof,
        uint256 _leaf
    ) internal pure returns (uint256) {
        uint256 proofElement;
        uint256 computedHash = _leaf;

        for (uint256 i = 0; i < _proof.length; i++) {
            // avoid array dereference bound check
            unchecked {
                proofElement = _proof[i];
            }
            computedHash = _hashBranch(computedHash, proofElement);
        }

        return computedHash;
    }

    // TODO: support _onBefore/AfterUpdate hooks
    function updateItem(
        uint256 _index,
        uint256[] calldata _depositProof,
        bytes calldata value
    ) external payable {
        require(
            _depositProof.length == TREE_HEIGHT,
            "proofs length must be TREE_HEIGHT"
        );

        // user's leaf
        uint256 oldLeaf;
        uint256 newLeaf;
        {
            uint256 item = $items[_index];
            
            oldLeaf = _hashLeaf(abi.encodePacked(item));
            newLeaf = _hashLeaf(value);
            // console.log("old leaf: %x", oldLeaf);
            // console.log("new leaf: %x", newLeaf);

            $items[_index] = abi.decode(value, (uint256));
        }

        {
            // calcuate root from commitment proof
            uint256 preUpdateRoot = _calcRoot(_depositProof, oldLeaf);

            // verify commitment proof was valid
            require(preUpdateRoot == $rootHash, "invalid pre-update root");
        }

        // the following section is non-trivial
        // so far we:
        // 1. verified deposit proof is valid
        // 2. modify leaf, calculate new root
        // but now also need to fix subtrees for the next deposits
        // and we also need to prove that the new subtrees correspond
        // to the new merkle tree by calculating the root from the last leaf
        // because we know the deposit tree proof, we can calculate the new root
        // and ensure that was the *only* change in the tree
        // thus if we calculate the new subtrees give the same root, we know it
        // belongs to the same new modified tree
        {
            // calculate new root to ensure no other elements were modified
            uint256 postUpdateRoot = newLeaf;

            // update rmln with new proof
            uint256 lastIndex = $countItems;
            uint256 currentIndex = _index;
            uint256 sibling;

            bool needUpdate = true;

            for (uint256 i = 0; i < TREE_HEIGHT; i++) {
                // AUDIT-NOTE: this logic requires extra attention under magnifying glass
                // lots of pitfalls here and I'm not sure still if this is legit...
                unchecked {
                    if (needUpdate && (currentIndex & 1) == 0 && (lastIndex ^ currentIndex) < 2) {
                        needUpdate = false;
                        $rmln[i] = postUpdateRoot;
                    }

                    sibling = _depositProof[i];
                }

                postUpdateRoot = _hashBranch(
                    postUpdateRoot,
                    sibling
                );

                lastIndex >>= 1;
                currentIndex >>= 1;
            }

            // finally overwrite older roots containing updated commitment
            $rootHash = postUpdateRoot;
        }
    }

    function appendItem(
        bytes calldata value
    ) external payable {
        uint256 newLeaf = _hashLeaf(value);
        // TODO: use get/setItem properly here and in updateItem...
        uint256 index = $countItems;
        // TODO: _onBeforeUpdate() here
        $items[index] = abi.decode(value, (uint256));

        // calculate new root to ensure no other elements were modified
        uint256 postUpdateRoot = newLeaf;

        // update rmln with new proof
        uint256 sibling;

        bool needUpdate = true;

        for (uint256 i = 0; i < TREE_HEIGHT; i++) {
            // AUDIT-NOTE: this logic requires extra attention under magnifying glass
            // lots of pitfalls here and I'm not sure still if this is legit...
            unchecked {
                if (index % 2 == 0) {
                    if (needUpdate) {
                        $rmln[i] = postUpdateRoot;
                        needUpdate = false;
                    }
                    sibling = $zeros[i];
                } else {
                    sibling = $rmln[i];
                }
            }

            postUpdateRoot = _hashBranch(
                postUpdateRoot,
                sibling
            );

            index >>= 1;
        }

        $countItems++;
        $rootHash = postUpdateRoot;

        // TODO: _onAfterUpdate() here
    }
}
