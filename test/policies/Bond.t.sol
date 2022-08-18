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
import { IBond, Bond } from "src/policies/Bond.sol";


contract BondTest is Test, IBond {
    Kernel internal kernel;

    MockERC20 internal DAI;

    Bond internal bond;
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
        DAI.mint(user1, 1_000_000*1e18);
        DAI.mint(user2, 1_000_000*1e18);
        DAI.mint(user3, 1_000_000*1e18);

        // deploy default kernel
        kernel = new Kernel();
        VOTES = new DefaultVotes(kernel);
        bond = new Bond(kernel, DAI);

        // deploy treasury
        ERC20[] memory approvedTokens = new ERC20[](2);
        approvedTokens[0] = ERC20(DAI);
        approvedTokens[1] = ERC20(VOTES);
        TRSRY = new DefaultTreasury(kernel, approvedTokens);

        // set up kernel
        kernel.executeAction(Actions.InstallModule, address(VOTES));
        kernel.executeAction(Actions.InstallModule, address(TRSRY));
        kernel.executeAction(Actions.ActivatePolicy, address(bond));
    }

    function testCorrectness_Initialize() public {
        assertEq(bond.EMISSION_RATE(), 25000);
        assertEq(bond.PRICE_DECAY_RATE(), 187_500);
        assertEq(bond.MAX_INVENTORY(), 1_000_000);
        assertEq(bond.RESERVE_PRICE(), 1_000_000);
        assertEq(bond.basePrice(), 1_000_000);
        assertEq(bond.prevSaleTimestamp(), block.timestamp);
        assertEq(bond.getCurrentInventory(), 400_000);
    }

    function testCorrectness_Purchase() public {
        vm.startPrank(user1);

        // variants
        uint256 amtToPurchase = 100;
        (uint256 totalCost, ) = bond.getTotalCost(amtToPurchase);
        uint256 startingBalance = DAI.balanceOf(address(user1));

        // purchase bond
        DAI.approve(address(TRSRY), totalCost*1e12);
        bond.purchase(amtToPurchase, totalCost);

        // assert dai has been transfered
        assertEq(DAI.balanceOf(address(user1)), startingBalance - totalCost*1e12);

        // assert that votes have been received
        assertEq(
            VOTES.balanceOf(address(user1)),
            amtToPurchase*10**VOTES.decimals()
        );

        vm.stopPrank();
    }

    function testCorrectness_PurchaseWithTimeDecay() public {
        vm.startPrank(user2);

        uint256 amtToPurchase1 = 128_500;
        (
            uint256 totalCost,
            uint256 newBasePrice
        ) = bond.getTotalCost(amtToPurchase1);
        
        // purchase 128500 tokens
        // so if slippage is 15 then
        // ( $1 + (.000015 * 128500) ) => totalCost should equal 2927500
        DAI.approve(address(TRSRY), totalCost*1e12);
        bond.purchase(amtToPurchase1, totalCost);

        // current base price is now $2.92
        // $2.92 - 28440 second price decay => $2.92 - $.617187 = $2.310313
        vm.warp(block.timestamp + 3 days + 7 hours);

        // assert base price has decayed to expected amount
        // add 1 slippage (.000015) to find the new base cost after price decay
        (totalCost, newBasePrice) = bond.getTotalCost(1);
        assertEq(newBasePrice, 2310313 + bond.SLIPPAGE_RATE());

        // total cost should be the average of the prev basePrice (2310313) new basePrice (2310313 + 15)
        // so (2310313 + (2310313 + slippage)) / 2
        assertEq(totalCost, (2310313 + 2310313 + bond.SLIPPAGE_RATE()) / 2);

        vm.stopPrank();
    }

    function testCorrectness_getCurrentInventory() public {

        // ensure starting inventory is set to hardcoded value of 400_000
        assertEq(bond.getCurrentInventory(), 400_000);

        vm.warp(block.timestamp + 5 days);

        // assert that inventory is inflated at expected rate
        assertEq(
            bond.getCurrentInventory(),
            400_000 + (bond.EMISSION_RATE() * 5)
        );

    }

    function testCorrectness_getTotalCost() public {
        vm.startPrank(user1);

        uint256 amt = 100_000;

        // get the cost of 100k bonds
        (uint256 totalCost, uint256 newBasePrice) = bond.getTotalCost(amt);

        // newBasePrice should be 1m + (basePrice * slippage)
        assertEq(newBasePrice, bond.basePrice() + (amt * bond.SLIPPAGE_RATE()));
        
        // total cost should be amtPurchased * ((basePrice + newBasePrice) / 2)
        assertEq(totalCost, amt * ((bond.basePrice() + newBasePrice) / 2) );

        // purchase 100k bonds
        DAI.approve(address(TRSRY), totalCost*1e12);
        bond.purchase(amt, totalCost);

        // basePrice() return value should equal newBasePrice from
        // previous getTotalCost call.
        assertEq(bond.basePrice(), newBasePrice);

        // get the cost of another 100k bonds
        (totalCost, newBasePrice) = bond.getTotalCost(amt);

        // verify updated newBasePrice value is as expected
        assertEq(newBasePrice, bond.basePrice() + (amt * bond.SLIPPAGE_RATE()));

        // verify updated totalCost value is as expected
        assertEq(totalCost, amt * ((bond.basePrice() + newBasePrice) / 2) );

        vm.stopPrank();
    }

    function testCorrectness_getTotalCostDecay() public {
        vm.startPrank(user1);

        uint256 amt = 100_000;
        (uint256 totalCost, uint256 newBasePrice) = bond.getTotalCost(amt);
        
        // simulate large purchase
        DAI.approve(address(TRSRY), totalCost*1e12);
        bond.purchase(amt, totalCost);

        // let price decay to the reserve price
        vm.warp(block.timestamp + 1000 days);

        // newBasePrice should be equal to reserve price + slippage
        (, newBasePrice) = bond.getTotalCost(1);
        assertEq(
            newBasePrice,
            bond.RESERVE_PRICE() + bond.SLIPPAGE_RATE()
        );

        vm.stopPrank();
    }

    function testCorrectness_PurchaseMultiple() public {
        vm.startPrank(user1);

        uint256 decimals = VOTES.decimals();

        uint256 startingBalance = DAI.balanceOf(address(user1));

        uint256 amtToPurchase1 = 50_000;
        (uint256 totalCost1, ) = bond.getTotalCost(amtToPurchase1);

        // bond purchase order #1
        DAI.approve(address(TRSRY), totalCost1*1e12);
        bond.purchase(amtToPurchase1, totalCost1);

        // assert dai has been transfered
        assertEq(DAI.balanceOf(address(user1)), startingBalance - totalCost1*1e12);

        // assert that votes have been received
        assertEq(
            VOTES.balanceOf(address(user1)),
            amtToPurchase1 * 10**decimals
        );

        vm.warp(block.timestamp + 1 days);

        uint256 amtToPurchase2 = 100_000;
        (uint256 totalCost2,) = bond.getTotalCost(amtToPurchase2);

        // bond purchase order #2
        DAI.approve(address(TRSRY), totalCost2*1e12);
        bond.purchase(amtToPurchase2, totalCost2);

        // assert dai has been transfered
        assertEq(
            DAI.balanceOf(address(user1)),
            startingBalance - totalCost1*1e12 - totalCost2*1e12
        );

        // assert that votes have been received
        assertEq(
            VOTES.balanceOf(address(user1)),
            (amtToPurchase1 + amtToPurchase2) * 10**decimals
        );

        vm.warp(block.timestamp + 2 days);

        uint256 amtToPurchase3 = 150_000;
        (uint256 totalCost3,) = bond.getTotalCost(amtToPurchase3);

        // bond purchase order #3
        DAI.approve(address(TRSRY), totalCost3*1e12);
        bond.purchase(amtToPurchase3, totalCost3);

        // assert dai has been transfered
        assertEq(
            DAI.balanceOf(address(user1)),
            startingBalance - totalCost1*1e12 - totalCost2*1e12 - totalCost3*1e12
        );

        // assert that votes have been received
        assertEq(
            VOTES.balanceOf(address(user1)),
            (amtToPurchase1 + amtToPurchase2 + amtToPurchase3) * 10**decimals
        );

        vm.stopPrank();

    }

    function testRevert_Purchase_ExecutionPriceTooHigh() public {
        vm.startPrank(user1);
        
        DAI.approve(address(TRSRY), 1);

        vm.expectRevert(IBond.ExecutionPriceTooHigh.selector);
        bond.purchase(1, 1);
        
        vm.stopPrank();
    }

    function testRevert_Purchase_NotEnoughInventory() public {
        vm.startPrank(user1);
        
        uint256 totalDai = DAI.balanceOf(address(user1));
        DAI.approve(address(TRSRY), totalDai);

        vm.expectRevert(IBond.NotEnoughInventory.selector);
        bond.purchase(400_001, totalDai);
        
        vm.stopPrank();
    }

}
