// SPDX-License-Identifier: MIT
// Merkle Tree by @high_byte

pragma solidity 0.8.0;

contract MerkleTree {
    uint256 public immutable TREE_HEIGHT;
    uint256 public immutable MAX_NODES;
    uint256 public immutable EMPTY_LEAF;
    uint256 public immutable ITEM_SIZE;

    uint256 public $rootHash;
    uint256 public $countItems;
    mapping(uint256 /*index*/ => uint256 /*ptr_base*/) public $items;

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
            hash = _hashBranch(hash, hash);
        }

        $rootHash = hash;
    }

    function _hashLeaf(
        bytes memory raw_bytes
    ) internal view virtual returns (uint256 hash) {
        hash = uint256(keccak256(raw_bytes));
    }

    function _hashBranch(
        uint256 hash1,
        uint256 hash2
    ) internal view virtual returns (uint256 hash) {
        if (hash1 > hash2) {
            hash = uint256(keccak256(abi.encode(hash1, hash2)));
        } else {
            hash = uint256(keccak256(abi.encode(hash2, hash1)));
        }
    }

    // NOTE: this does not do range checks (empty _proof will simply return _leaf)
    function _calcRoot(
        uint256[] calldata _proof,
        uint256 _leaf
    ) internal view returns (uint256) {
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

    function _getSlot(uint256 index) internal pure returns (uint256 slot) {
        /// @solidity memory-safe-assembly
        assembly {
            slot := $items.slot
        }
        slot = uint256(keccak256(abi.encode(index, slot)));
    }

    // NOTE: this allocates new memory for each item. find a way to fix this.
    function _getItem(uint256 index) internal view returns (bytes memory item) {
        item = new bytes(ITEM_SIZE);
        uint256 item_size = ITEM_SIZE;
        uint256 item_slot = _getSlot(index);
        /// @solidity memory-safe-assembly
        assembly {
            let item_off := add(item, 32)
            for {
                let i := 0
            } lt(i, item_size) {
                i := add(i, 32)
            } {
                mstore(item_off, sload(item_slot))
                item_off := add(item_off, 32)
                item_slot := add(item_slot, 1)
            }
        }
    }

    function _setItem(uint256 index, bytes memory item) internal {
        uint256 item_size = ITEM_SIZE;
        uint256 item_slot = _getSlot(index);
        /// @solidity memory-safe-assembly
        assembly {
            let item_off := add(item, 32)
            for {
                let i := 0
            } lt(i, item_size) {
                i := add(i, 32)
            } {
                sstore(item_slot, mload(item_off))
                item_off := add(item_off, 32)
                item_slot := add(item_slot, 1)
            }
        }
    }

    function getAccessList(
        uint256[] calldata indices
    ) external view returns (uint256[] memory access_list) {
        uint256 size = (ITEM_SIZE + 31) / 32;
        access_list = new uint256[](indices.length * size + 1);
        uint256 rootHashSlot;
        /// @solidity memory-safe-assembly
        assembly {
            rootHashSlot := $rootHash.slot
        }
        access_list[access_list.length - 1] = rootHashSlot;
        for (uint256 i = 0; i < access_list.length; i += size) {
            uint256 slot = _getSlot(indices[i]);
            for (uint256 j = 0; j < size; j++) {
                access_list[i + j] = slot + j;
            }
        }
    }

    function updateItem(
        uint256 index,
        uint256[] calldata proof,
        bytes calldata params
    ) public payable {
        require(
            proof.length == TREE_HEIGHT,
            "proofs length must be TREE_HEIGHT"
        );
        require(index < MAX_NODES, "tree is full");
        uint256 lastIndex = $countItems;
        require(index <= lastIndex, "[u] index out of bounds");

        bytes memory item = _getItem(index);

        // pre-update root verification
        uint256 oldLeaf = _hashLeaf(item);
        uint256 preUpdateHash = _calcRoot(proof, oldLeaf);
        require(preUpdateHash == $rootHash, "invalid pre-update root");

        // update item in-memory
        item = _onBeforeUpdate(index, item, params);

        // post-update root calculation
        uint256 newLeaf = _hashLeaf(item);
        $rootHash = _calcRoot(proof, newLeaf);

        // apply updates to storage
        _setItem(index, item);
        if (index == lastIndex) {
            $countItems++;
        }

        // call post-update hooks
        _onAfterUpdate(index, item, params);
    }

    function updateBatchItems(
        uint256[] calldata indices,
        uint256[][] calldata proofs,
        bytes[] calldata paramsArray
    ) public payable {
        uint256 len = indices.length;
        require(
            len == proofs.length && len == paramsArray.length,
            "batches length must match"
        );
        for (uint256 i = 0; i < len; i++) {
            updateItem(indices[i], proofs[i], paramsArray[i]);
        }
    }

    function _onBeforeUpdate(
        uint256 index,
        bytes memory item,
        bytes calldata params
    ) internal view virtual returns (bytes memory) {
        // override this function to apply updates to the item
        // this is a view function as you should not call any state-changing functions here (do this in _onAfterUpdate)
        // default behaviour is stupid - just copy all params to all items (and their lengths must be the same)
        require(
            item.length == params.length,
            "item and params must be same length"
        );
        assembly {
            calldatacopy(add(item, 32), params.offset, mload(item))
        }
        return item;
    }

    function _onAfterUpdate(
        uint256 index,
        bytes memory item,
        bytes calldata params
    ) internal virtual {
        // no-op
        // any post-update effects should be implemented here to follow proper Checks-Effects-Interactions pattern
    }
}
