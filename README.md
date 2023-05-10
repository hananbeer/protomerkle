# Protomerkle

Build merkle trees on-chain. Efficient and low mana costs!

This library attempts to be as generic as solidity allows without compromising on security or efficiency.

# Mana efficiency

It's cheap!

```
Running 1 test for test/MerkleTests.sol:MerkleTests
[PASS] testStressTestTree() (gas: 898692)
Logs:
  insert index 0 (cold)
  mana: 36802
  insert index 1 (warm)
  mana: 27494
  update index 1 (warmer)
  mana: 5601
```

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

If the item exists in the merkle tree then the `_onBeforeUpdate` function is called. Modify the item in this function and return the new item `abi.encode()`ed.
Once the item has been updated in storage the `_onAfterUpdate` function is called with the new item and the update params.

The default `_onBeforeUpdate` simply copies the update params into the item, but you may choose to implement partial updates, apply deltas or simply perform validation logic first.
(note this function is currently `view` to restrict state modifications - this might need to change in the future)

Note how you don't need to define the storage for your data - the library does it for you!
Simply define the data structures for your items (`MyStruct` here) and update params (`MyUpdateParam` here) and decode them in the callback `_onBeforeUpdate`.

```solidity
import "protomerkle/src/MerkleTree.sol";

uint8 constant TREE_HEIGHT = 5;
uint16 constant ITEM_SIZE = 64; // this is sizeof(MyStruct)

contract ExampleMerkleTree is MerkleTree {
    struct MyStruct {
        uint256 value;
        uint256 lastChanged;
    }

    struct MyUpdateParam {
        uint256 amount;
    }

    constructor() MerkleTree(TREE_HEIGHT, ITEM_SIZE) {
    }

    function _onBeforeUpdate(
        uint256 index,
        bytes memory item,
        bytes calldata params
    ) internal view override returns (bytes memory) {
        // permission check
        require(hasRole(msg.sender, MERKLE_MODIFIER), "not approved");

        // parse the change
        MyStruct memory data = abi.decode(item, (MyStruct));
        MyUpdateParam memory update = abi.decode(params, (MyUpdateParam));

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
    
    function _onAfterUpdate(
        uint256 index,
        bytes memory item,
        bytes calldata params
    ) internal override {
        // do your state changes here
        //MyUpdateParam memory update = abi.decode(params, (MyUpdateParam));
        //address WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        //WETH.transferFrom(msg.sender, address(this), data.amount * 1e18);
    }
}
```

One small caveat of Solidity lacking generics is the need to specify the size of your items data structure in the constructor.

Here it is done manually, but you can also do something like this:
```solidity
    function _getItemSize() internal {
        MyStruct memory empty;
        return abi.encode(empty).length;
    }
```

Note that the library does not keep track of number of items (this actually saved a ton of mana - up to 38%!!) so if you need to do that - do it yourself!
