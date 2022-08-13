// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { UserFactory } from "test-utils/UserFactory.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import { Kernel, Actions } from "src/Kernel.sol";
import { DefaultVotes } from "src/modules/VOTES.sol";
import { DefaultTreasury } from "src/modules/TRSRY.sol";
import { Bond, IBond } from "src/policies/Bond.sol";

contract BondTest is Test {
    Kernel internal kernel;

    MockERC20 internal DAI;

    Bonds internal bonds;
    DefaultVotes internal VOTES;
    DefaultTreasury internal TRSRY;

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

        DAI = new MockERC20("DAI", "DAI", 18);
        DAI.mint(user1, 1000*1e18);
        DAI.mint(user2, 1000*1e18);
        DAI.mint(user3, 1000*1e18);

        // deploy default kernel
        kernel = new Kernel();
        VOTES = new DefaultVotes(kernel);
        bonds = new Bonds(kernel, DAI);

        // deploy treasury
        ERC20[] memory approvedTokens = new ERC20[](2);
        approvedTokens[0] = ERC20(DAI);
        approvedTokens[1] = ERC20(VOTES);
        TRSRY = new DefaultTreasury(kernel, approvedTokens);

        // set up kernel
        kernel.executeAction(Actions.InstallModule, address(VOTES));
        kernel.executeAction(Actions.InstallModule, address(TRSRY));
        kernel.executeAction(Actions.ApprovePolicy, address(bonds));
    }

    function testCorrectness_Initialize() public {
        assertEq(bonds.EMISSION_RATE(), 25000);
        assertEq(bonds.PRICE_DECAY_RATE(), 187_500);
        assertEq(bonds.MAX_INVENTORY(), 1_000_000);
        assertEq(bonds.RESERVE_PRICE(), 1_000_000);
        assertEq(bonds.basePrice(), 1_000_000);
        assertEq(bonds.prevSaleTimestamp(), 0);
        assertEq(bonds.getCurrentInventory(), 400_000);
    }

    function testCorrectness_PurchaseSingleBond() public {
        vm.startPrank(user1);

        // variants
        uint256 amtToPurchase = 1;
        (uint256 totalCost, ) = bonds.getTotalCost(amtToPurchase);
        uint256 startingBalance = DAI.balanceOf(address(user1));

        // purchase bond
        DAI.approve(address(TRSRY), totalCost);
        bonds.purchase(amtToPurchase, totalCost);

        // assert that dai has been transfered
        assertEq(DAI.balanceOf(address(user1)), startingBalance - totalCost);

        // assert that votes have been received
        assertEq(VOTES.balanceOf(address(user1)), amtToPurchase);

        vm.stopPrank();
    }

    function testCorrectness_PurchaseManyBonds() public {
        vm.startPrank(user2);

        // variants
        uint256 amtToPurchase = 100;
        (uint256 totalCost, ) = bonds.getTotalCost(amtToPurchase);
        uint256 startingBalance = DAI.balanceOf(address(user1));

        // purchase bond
        DAI.approve(address(TRSRY), totalCost);
        bonds.purchase(amtToPurchase, totalCost);

        // assert dai has been transfered
        assertEq(DAI.balanceOf(address(user2)), startingBalance - totalCost);

        // assert that votes have been received
        assertEq(VOTES.balanceOf(address(user2)), amtToPurchase);

        vm.stopPrank();
    }

    // function testCorrectness_PurchaseSingleBatch() public {
    //     uint256 cost = bond.purchase(500, 100);
    //     assertEq(cost, 50000);
    // }

    // function testCorrectness_PurchaseMultipleBatches() public {
    //     uint256 cost = bond.purchase(25500, 140);
    //     assertEq(cost, 3187500);
    // }


    // function testCorrectness_PurchaseWithResidual() public {
    //     uint256 cost = bond.purchase(666, 102);
    //     assertEq(cost, 66766);
    // }

    // function testCorrectness_PurchaseWithOffset() public {
    //     bond.purchase(135, 102);

    //     uint256 cost = bond.purchase(500, 102);
    //     assertEq(cost, 50135);
    // }

    // function testCorrectness_PurchaseWithTimeDecay() public {
    //     bond.purchase(128500, 500); // 128500 tokens purchased => +$2.57 slippage

    //     // base price = $3.57
    //     vm.warp(block.timestamp + 3 days + 7 hours); // 284400 seconds elapsed => -$0.82 decay

    //     // base price = $2.75
    //     uint256 cost = bond.purchase(500, 275);
    //     assertEq(cost, 137500);
    // }

    // function testCorrectness_MultiplePurchaseTransactions() public {
    //     uint256 cost = bond.purchase(500, 100);
    //     assertEq(cost, 50000);

    //     // price: 101
    //     // offset: 0
    //     cost = bond.purchase(500, 101);
    //     assertEq(cost, 50500);

    //     // price: 102
    //     // offset: 166
    //     cost = bond.purchase(666, 103);
    //     assertEq(cost, 68098);

    //     // price: 104
    //     // offset: 108
    //     cost = bond.purchase(942, 104);
    //     assertEq(cost, 97742);

    //     vm.warp(block.timestamp + (3 days / 25)); // -$0.03 decay

    //     // price: 101
    //     // offset: 108
    //     cost = bond.purchase(500, 102);
    //     assertEq(cost, 50608);
    // }

    //  function testRevert_NotEnoughInventory() public {
    //     vm.expectRevert(NotEnoughInventory.selector);
    //     bond.purchase(400_001, 500);

    //     bond.purchase(400_000, 500);
    //     assertEq(bond.basePrice(), 900);

    //     // price is $9.00 after slippage
    //     vm.expectRevert(NotEnoughInventory.selector);
    //     bond.purchase(1, 500);

    //     vm.warp(block.timestamp + 1 days);  // + 25,000 PRXY tokens PRXY

    //     vm.expectRevert(NotEnoughInventory.selector);
    //     bond.purchase(25001, 900);


    //     // price is $8.75 after decay
    //     uint256 cost = bond.purchase(25000, 900);
    //     assertEq(cost, 22_487_500);
    // }

    // function testRevert_ExecutionPriceTooHigh() public {
    //     vm.expectRevert(ExecutionPriceTooHigh.selector);
    //     bond.purchase(666, 100);

    //     vm.expectRevert(ExecutionPriceTooHigh.selector);
    //     bond.purchase(1800, 101);
    // }

}
