// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { UserFactory } from "test-utils/UserFactory.sol";
import "src/Kernel.sol";
import "src/modules/VOTES.sol";
import "src/policies/Bonds.sol";


contract BondsTest is Test {
    Kernel internal kernel;
    DefaultVotes internal VOTES;
    Bonds internal bonds;

    UserFactory public userFactory;
    address public user1;
    address public user2;
    address public user3;

    bytes public err;

    function setUp() public {
        userFactory = new UserFactory();
        address[] memory users = userFactory.create(3);
        user1 = users[0];
        user2 = users[1];
        user3 = users[2];

        kernel = new Kernel();
        VOTES = new DefaultVotes(kernel);
        bonds = new Bonds(kernel);
    }

    function testCorrectness_Initialize() public {
        assertEq(bonds.EMISSION_RATE(), 25000);
        assertEq(bonds.BATCH_SIZE(), 500);
        assertEq(bonds.PRICE_DECAY_RATE(), 25);
        assertEq(bonds.MAX_INVENTORY(), 1000000);
        assertEq(bonds.RESERVE_PRICE(), 100);
        assertEq(bonds.basePrice(), 100);
        assertEq(bonds.prevSaleTimestamp(), 0);
        assertEq(bonds.inventory(), 400000);
        assertEq(bonds.tokenOffset(), 0);
    }

    function testCorrectness_PurchaseSingleBatch() public {
        uint256 cost = bonds.purchase(500, 100);
        assertEq(cost, 50000);
    }

    function testCorrectness_PurchaseMultipleBatches() public {
        uint256 cost = bonds.purchase(25500, 140);
        assertEq(cost, 3187500);
    }


    function testCorrectness_PurchaseWithResidual() public {
        uint256 cost = bonds.purchase(666, 102);
        assertEq(cost, 66766);
    }

    function testCorrectness_PurchaseWithOffset() public {
        bonds.purchase(135, 102);

        uint256 cost = bonds.purchase(500, 102);
        assertEq(cost, 50135);
    }

    function testCorrectness_PurchaseWithTimeDecay() public {
        bonds.purchase(128500, 500); // 128500 tokens purchased => +$2.57 slippage

        // base price = $3.57
        vm.warp(block.timestamp + 3 days + 7 hours); // 284400 seconds elapsed => -$0.82 decay

        // base price = $2.75
        uint256 cost = bonds.purchase(500, 275);
        assertEq(cost, 137500);
    }

    function testCorrectness_MultiplePurchaseTransactions() public {
        uint256 cost = bonds.purchase(500, 100);
        assertEq(cost, 50000);

        // price: 101
        // offset: 0
        cost = bonds.purchase(500, 101);
        assertEq(cost, 50500);

        // price: 102
        // offset: 166
        cost = bonds.purchase(666, 103);
        assertEq(cost, 68098);

        // price: 104
        // offset: 108
        cost = bonds.purchase(942, 104);
        assertEq(cost, 97742);

        vm.warp(block.timestamp + (3 days / 25)); // -$0.03 decay

        // price: 101
        // offset: 108
        cost = bonds.purchase(500, 102);
        assertEq(cost, 50608);
    }

     function testRevert_NotEnoughInventory() public {
        vm.expectRevert(NotEnoughInventory.selector);
        bonds.purchase(400_001, 500);

        bonds.purchase(400_000, 500);
        assertEq(bonds.basePrice(), 900);

        // price is $9.00 after slippage
        vm.expectRevert(NotEnoughInventory.selector);
        bonds.purchase(1, 500);

        vm.warp(block.timestamp + 1 days);  // + 25,000 PRXY tokens PRXY

        vm.expectRevert(NotEnoughInventory.selector);
        bonds.purchase(25001, 900);


        // price is $8.75 after decay
        uint256 cost = bonds.purchase(25000, 900);
        assertEq(cost, 22_487_500);
    }

    function testRevert_ExecutionPriceTooHigh() public {
        vm.expectRevert(ExecutionPriceTooHigh.selector);
        bonds.purchase(666, 100);

        vm.expectRevert(ExecutionPriceTooHigh.selector);
        bonds.purchase(1800, 101);
    }

}
