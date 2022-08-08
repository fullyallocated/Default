// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity ^0.8.15;

// import { Test } from "forge-std/Test.sol";
// import { UserFactory } from "test-utils/UserFactory.sol";
// import { ERC20 } from "solmate/tokens/ERC20.sol";
// import "src/Kernel.sol";
// import "src/modules/VOTES.sol";
// import "src/policies/Bond.sol";

// contract MockDAI is ERC20("DAI", "DAI", 18) {
    
//     function mint(address to_, uint256 amt_) public {
//         _mint(to_, amt_);
//     }
// }

// contract BondTest is Test, IBond {
//     Kernel internal kernel;
//     DefaultVotes internal VOTES;
//     Bond internal bond;

//     UserFactory public userFactory;
//     address public user1;
//     address public user2;
//     address public user3;

//     ERC20 public DAI;    

//     bytes public err;

//     function setUp() public {
//         userFactory = new UserFactory();
//         address[] memory users = userFactory.create(3);
//         user1 = users[0];
//         user2 = users[1];
//         user3 = users[2];

//         DAI = new MockDAI();

//         kernel = new Kernel();
//         VOTES = new DefaultVotes(kernel);
//         bond = new Bond(kernel, DAI); // <= create fake token addr
//     }

//     function testCorrectness_Initialize() public {
//         assertEq(bond.EMISSION_RATE(), 25000);
//         assertEq(bond.PRICE_DECAY_RATE(), 187_500);
//         assertEq(bond.MAX_INVENTORY(), 1_000_000);
//         assertEq(bond.RESERVE_PRICE(), 1_000_000);
//         assertEq(bond.basePrice(), 1_000_000);
//         assertEq(bond.prevSaleTimestamp(), 0);
//         assertEq(bond.inventory(), 400_000);
//     }

//     // function testCorrectness_PurchaseSingleBatch() public {
//     //     uint256 cost = bond.purchase(500, 100);
//     //     assertEq(cost, 50000);
//     // }

//     // function testCorrectness_PurchaseMultipleBatches() public {
//     //     uint256 cost = bond.purchase(25500, 140);
//     //     assertEq(cost, 3187500);
//     // }


//     // function testCorrectness_PurchaseWithResidual() public {
//     //     uint256 cost = bond.purchase(666, 102);
//     //     assertEq(cost, 66766);
//     // }

//     // function testCorrectness_PurchaseWithOffset() public {
//     //     bond.purchase(135, 102);

//     //     uint256 cost = bond.purchase(500, 102);
//     //     assertEq(cost, 50135);
//     // }

//     // function testCorrectness_PurchaseWithTimeDecay() public {
//     //     bond.purchase(128500, 500); // 128500 tokens purchased => +$2.57 slippage

//     //     // base price = $3.57
//     //     vm.warp(block.timestamp + 3 days + 7 hours); // 284400 seconds elapsed => -$0.82 decay

//     //     // base price = $2.75
//     //     uint256 cost = bond.purchase(500, 275);
//     //     assertEq(cost, 137500);
//     // }

//     // function testCorrectness_MultiplePurchaseTransactions() public {
//     //     uint256 cost = bond.purchase(500, 100);
//     //     assertEq(cost, 50000);

//     //     // price: 101
//     //     // offset: 0
//     //     cost = bond.purchase(500, 101);
//     //     assertEq(cost, 50500);

//     //     // price: 102
//     //     // offset: 166
//     //     cost = bond.purchase(666, 103);
//     //     assertEq(cost, 68098);

//     //     // price: 104
//     //     // offset: 108
//     //     cost = bond.purchase(942, 104);
//     //     assertEq(cost, 97742);

//     //     vm.warp(block.timestamp + (3 days / 25)); // -$0.03 decay

//     //     // price: 101
//     //     // offset: 108
//     //     cost = bond.purchase(500, 102);
//     //     assertEq(cost, 50608);
//     // }

//     //  function testRevert_NotEnoughInventory() public {
//     //     vm.expectRevert(NotEnoughInventory.selector);
//     //     bond.purchase(400_001, 500);

//     //     bond.purchase(400_000, 500);
//     //     assertEq(bond.basePrice(), 900);

//     //     // price is $9.00 after slippage
//     //     vm.expectRevert(NotEnoughInventory.selector);
//     //     bond.purchase(1, 500);

//     //     vm.warp(block.timestamp + 1 days);  // + 25,000 PRXY tokens PRXY

//     //     vm.expectRevert(NotEnoughInventory.selector);
//     //     bond.purchase(25001, 900);


//     //     // price is $8.75 after decay
//     //     uint256 cost = bond.purchase(25000, 900);
//     //     assertEq(cost, 22_487_500);
//     // }

//     // function testRevert_ExecutionPriceTooHigh() public {
//     //     vm.expectRevert(ExecutionPriceTooHigh.selector);
//     //     bond.purchase(666, 100);

//     //     vm.expectRevert(ExecutionPriceTooHigh.selector);
//     //     bond.purchase(1800, 101);
//     // }

// }
