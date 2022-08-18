// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "src/Kernel.sol";

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { UserFactory } from "test-utils/UserFactory.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import { DefaultVotes } from "src/modules/VOTES.sol";
import { DefaultTreasury } from "src/modules/TRSRY.sol";
import { IRedemption, Redemption } from "src/policies/Redemption.sol";

import "../lib/ModuleTestFixtureGenerator.sol";


contract RedemptionTest is Test {
  using ModuleTestFixtureGenerator for DefaultTreasury;
  using ModuleTestFixtureGenerator for DefaultVotes;

  // kernel
  Kernel internal kernel;

  // modules
  DefaultVotes internal VOTES;
  DefaultTreasury internal TRSRY;

  // policies
  Redemption internal redemption;

  MockERC20 internal DAI;

  UserFactory public userFactory;
  address public user1;
  address public user2;
  address public user3;

  address internal treasuryGod;
  address internal voteGod;

  bytes public err;

  function setUp() public {
    userFactory = new UserFactory();
    address[] memory users = userFactory.create(3);
    user1 = users[0];
    user2 = users[1];
    user3 = users[2];

    // deploy default kernel
    kernel = new Kernel();

    // deploy modules
    DAI = new MockERC20("DAI", "DAI", 18);
    ERC20[] memory approvedTokens = new ERC20[](1);
    approvedTokens[0] = ERC20(DAI);
    TRSRY = new DefaultTreasury(kernel, approvedTokens);
    
    VOTES = new DefaultVotes(kernel);

    // deploy redemption
    redemption = new Redemption(kernel);

    // generate fixtures
    treasuryGod = TRSRY.generateGodmodeFixture(type(DefaultTreasury).name);
    voteGod = VOTES.generateGodmodeFixture(type(DefaultVotes).name);

    // set up kernel
    kernel.executeAction(Actions.InstallModule, address(TRSRY));
    kernel.executeAction(Actions.InstallModule, address(VOTES));
    kernel.executeAction(Actions.ActivatePolicy, address(redemption));
    kernel.executeAction(Actions.ActivatePolicy, address(treasuryGod));
    kernel.executeAction(Actions.ActivatePolicy, address(voteGod));

    // mint a mil to TRSRY
    DAI.mint(address(TRSRY), 1_000_000*1e18);

    // mint to users
    // 1 vote backed by 1000 dai
    vm.startPrank(voteGod);
    VOTES.mintTo(user1, 200*1e3); // 20% of TRSRY
    VOTES.mintTo(user2, 200*1e3); // 20% of TRSRY
    VOTES.mintTo(user3, 600*1e3); // 60% of TRSRY
    vm.stopPrank();
  }

  function testCorrectness_Redeem() public {
    
    // redeem user1
    vm.startPrank(user1);
    VOTES.approve(address(TRSRY), VOTES.balanceOf(user1));
    redemption.redeem(VOTES.balanceOf(user1));

    // current TRSRY total = 1M DAI
    // user1 holds 200k/1M tokens = 20% of TRSRY = 200K
    // redeeming 20% * 95% * 200k = 190k redeemed
    assertEq(DAI.balanceOf(user1), 190_000*1e18);
    assertEq(DAI.balanceOf(address(TRSRY)), 810_000*1e18);

    vm.stopPrank();

    // redeem user2
    vm.startPrank(user2);
    VOTES.approve(address(TRSRY), VOTES.balanceOf(user2)); // only redeem half
    redemption.redeem(VOTES.balanceOf(user2));

    // current TRSRY total = 1M - 190k = 810k DAI
    // user2 holds 200k/800k tokens = 25% of TRSRY = 202.5k
    // redeeming 25% * 95% * 810k = 192,375 DAI
    assertEq(DAI.balanceOf(user2), 192_375*1e18);
    assertEq(DAI.balanceOf(address(TRSRY)), 617_625*1e18);

    vm.stopPrank();

    // redeem user3
    vm.startPrank(user3);
    VOTES.approve(address(TRSRY), VOTES.balanceOf(user3));
    redemption.redeem(VOTES.balanceOf(user3));

    // current TRSRY total = 810k - 192,375 = 617,625 DAI
    // user3 holds 600k/600k tokens = 100% of TRSRY = 617,625 DAI
    // redeeming 100% * 95% * 617,625 DAI = 586,743.75 DAI
    assertEq(DAI.balanceOf(user3), 586_74375*1e16);
    assertEq(DAI.balanceOf(address(TRSRY)), 30_88125*1e16);
    vm.stopPrank();
  }

  function testCorrectness_Redeem_MultiAsset() public {
    MockERC20 USDC = new MockERC20("USDC", "USDC", 6);
    
    // mint a mil to TRSRY
    vm.prank(treasuryGod);
    TRSRY.addReserveAsset(USDC);
    USDC.mint(address(TRSRY), 2_000_000*1e6);

    vm.startPrank(user1);
    VOTES.approve(address(TRSRY), VOTES.balanceOf(user1));
    redemption.redeem(VOTES.balanceOf(user1));

    // current TRSRY total = 1M DAI, 2M USDC
    // user1 holds 200k/1M tokens = 20% of TRSRY = 200k DAI, 400k USDC
    // redeeming 20% * 95% * (200k DAI, 200k USDC) = 190k DAI, 380k USDC
    assertEq(DAI.balanceOf(user1), 190_000*1e18);
    assertEq(DAI.balanceOf(address(TRSRY)), 810_000*1e18);
    
    assertEq(USDC.balanceOf(user1), 380_000*1e6);
    assertEq(USDC.balanceOf(address(TRSRY)), 1_620_000*1e6);
    vm.stopPrank();

  }

}