# Protomerkle

Build merkle trees on-chain. Efficient and low mana costs!

This library attempts to be as generic as solidity allows without compromising on security or efficiency.

# Testing

```
forge test -vv
```

# Integration

Install the library:

```
forge install hananbeer/protomerkle
```

The base library is `MerkleTree`, but there is also an extended `MerkleSumTree`:

```solidity
import "protomerkle/src/MerkleTree.sol";
```

The library has a method `updateItems` which is public payable (I probably need to change this to internal soon) which accepts an index of an item to update, inclusion proof and arbitrary update parameters. (bytes memory params)

If the item exists in the merkle tree then the `_onBeforeUpdate` function is called.

By default it simply copies the update params into the item, but you may choose to implement partial updates, apply deltas or simply perform validation logic first.
(note this function is currently `view` to restrict state modifications - this might need to change in the future)

```solidity

import "../src/MerkleTree.sol";

contract ExampleMerkleTree is MerkleTree {
    struct MyStruct {
        uint256 value;
        uint256 lastChanged;
    }

    struct MyUpdateParam {
        uint256 amount;
    }

    // merkle tree height = 5, item_size = sizeof(MyStruct)
    constructor() MerkleTree(5, 64) {
    }

    function _onBeforeUpdate(bytes memory item, bytes memory params) internal view override returns (bytes memory) {
        // simply permission check
        require(hasRole(msg.sender, MERKLE_MODIFIER), "not approved");

        // parse the change
        MyStruct memory data = abi.decode(item, (MyStruct));
        MyUpdateParam memory update = abi.decode(params, (MyUpdateParam));
        console.log("data.value: %d, update.amount: %d", data.value, update.amount);
        // soft limit the amount
        if (update.amount > 1000)
            update.amount = 1000;

        // apply a delta change
        data.value += update.amount * 1e18;

        // apply a change not coming from params
        data.lastChanged = block.timestamp;

        // make sure to return the item as bytes using abi.encode()
        // until solidity gets generics we are stuck with this raw bytes horror
        return abi.encode(data);
    }
}
```
