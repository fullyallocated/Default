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

    function testCorrectness_InitializeKernel() public {
        assertEq(bonds.EMISSION_RATE(), 25000);
        assertEq(bonds.BATCH_SIZE(), 500);
        assertEq(bonds.DECAY_RATE(), 25);
        assertEq(bonds.MAX_INVENTORY(), 1000000);
        assertEq(bonds.RESERVE_PRICE(), 100);
        assertEq(bonds.basePrice(), 100);
        assertEq(bonds.prevSaleTimestamp(), 0);
        assertEq(bonds.inventory(), 400000);
        assertEq(bonds.tokenOffset(), 0);
    }
}
