// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "src/Kernel.sol";
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { UserFactory } from "test-utils/UserFactory.sol";

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

import { Kernel, Actions } from "src/Kernel.sol";
import { DefaultTreasury } from "src/modules/TRSRY.sol";

import "../lib/ModuleTestFixtureGenerator.sol";

contract DefaultTreasuryTest is Test {
  using ModuleTestFixtureGenerator for DefaultTreasury;

  Kernel internal kernel;

  MockERC20 internal DAI;
  MockERC20 internal USDC;

  DefaultTreasury internal TRSRY;

  UserFactory internal userFactory;

  address internal godmode;

  address public user1;
  address public user2;
  address public user3;

  function setUp() public {

    // generate test users
    userFactory = new UserFactory();
    address[] memory users = userFactory.create(3);
    user1 = users[0];
    user2 = users[1];
    user3 = users[2];

    // deploy and mint mock DAI
    DAI = new MockERC20("DAI", "DAI", 18);
    DAI.mint(user1, 1_000_000*1e18);
    DAI.mint(user2, 1_000_000*1e18);
    DAI.mint(user3, 1_000_000*1e18);

    // deploy and mint mock USDC
    USDC = new MockERC20("USDC", "USDC", 6);
    USDC.mint(user1, 1_000_000*1e6);
    USDC.mint(user2, 1_000_000*1e6);
    USDC.mint(user3, 1_000_000*1e6);

    // deploy kernel and TRSRY module
    kernel = new Kernel();
    ERC20[] memory initialAssets = new ERC20[](2);
    initialAssets[0] = DAI;
    initialAssets[1] = USDC;
    TRSRY = new DefaultTreasury(kernel, initialAssets);

    // generate godmode address
    godmode = TRSRY.generateGodmodeFixture(type(DefaultTreasury).name);

    // set up kernel
    kernel.executeAction(Actions.InstallModule, address(TRSRY));
    kernel.executeAction(Actions.ActivatePolicy, godmode);
  }

  function testCorrectness_IsReserveAsset() public {
    assertTrue(TRSRY.isReserveAsset(DAI));
    assertTrue(TRSRY.isReserveAsset(USDC));
  }

  function testCorrectness_Withdraw() public {
    uint256 user1UsdcBalance = USDC.balanceOf(user1);
    uint256 user1DaiBalance = DAI.balanceOf(user1);

    uint256 user2UsdcBalance = USDC.balanceOf(user2);
    uint256 user2DaiBalance = DAI.balanceOf(user2);

    uint256 user3UsdcBalance = USDC.balanceOf(user3);
    uint256 user3DaiBalance = DAI.balanceOf(user3);
    
    vm.startPrank(user1);
    USDC.approve(address(TRSRY), user1UsdcBalance);
    DAI.approve(address(TRSRY), user1DaiBalance);
    vm.stopPrank();

    vm.startPrank(user2);
    USDC.approve(address(TRSRY), user2UsdcBalance);
    DAI.approve(address(TRSRY), user2DaiBalance);
    vm.stopPrank();

    vm.startPrank(user3);
    USDC.approve(address(TRSRY), user3UsdcBalance);
    DAI.approve(address(TRSRY), user3DaiBalance);
    vm.stopPrank();

    vm.startPrank(godmode);

    // deposit all assets into TRSRY
    TRSRY.depositFrom(user1, USDC, user1UsdcBalance);
    TRSRY.depositFrom(user1, DAI, user1DaiBalance);

    TRSRY.depositFrom(user2, USDC, user2UsdcBalance);
    TRSRY.depositFrom(user2, DAI, user2DaiBalance);

    TRSRY.depositFrom(user3, USDC, user3UsdcBalance);
    TRSRY.depositFrom(user3, DAI, user3DaiBalance);

    // withdraw all assets from TRSRY
    TRSRY.withdraw(USDC, USDC.balanceOf(address(TRSRY)));
    TRSRY.withdraw(DAI, DAI.balanceOf(address(TRSRY)));

    vm.stopPrank();

    // ensure usdc amount withdrawn equals amount deposited
    assertEq(
      USDC.balanceOf(address(godmode)),
      user1UsdcBalance + user2UsdcBalance + user3UsdcBalance
    );

    // ensure dai amount withdrawn equals amount deposited
    assertEq(
      DAI.balanceOf(address(godmode)),
      user1DaiBalance + user2DaiBalance + user3DaiBalance
    );

  }

  function testCorrectness_DepositFrom() public {
    uint256 user1UsdcBalance = 100*1e6;
    uint256 user1DaiBalance = 1*1e18;

    uint256 user2UsdcBalance = 92_384*1e6;
    uint256 user2DaiBalance = 734_123*1e18;

    uint256 user3UsdcBalance = 1*1e6;
    uint256 user3DaiBalance = DAI.balanceOf(user3);
    
    vm.startPrank(user1);
    USDC.approve(address(TRSRY), user1UsdcBalance);
    DAI.approve(address(TRSRY), user1DaiBalance);
    vm.stopPrank();

    vm.startPrank(user2);
    USDC.approve(address(TRSRY), user2UsdcBalance);
    DAI.approve(address(TRSRY), user2DaiBalance);
    vm.stopPrank();

    vm.startPrank(user3);
    USDC.approve(address(TRSRY), user3UsdcBalance);
    DAI.approve(address(TRSRY), user3DaiBalance);
    vm.stopPrank();

    vm.startPrank(godmode);

    // deposit all assets into TRSRY
    TRSRY.depositFrom(user1, USDC, user1UsdcBalance);
    TRSRY.depositFrom(user1, DAI, user1DaiBalance);

    TRSRY.depositFrom(user2, USDC, user2UsdcBalance);
    TRSRY.depositFrom(user2, DAI, user2DaiBalance);

    TRSRY.depositFrom(user3, USDC, user3UsdcBalance);
    TRSRY.depositFrom(user3, DAI, user3DaiBalance);

    vm.stopPrank();

    // ensure amount of USDC deposited equals expected amount
    assertEq(
      USDC.balanceOf(address(TRSRY)),
      user1UsdcBalance + user2UsdcBalance + user3UsdcBalance
    );

    // ensure amount of DAI deposited equals expected amount
    assertEq(
      DAI.balanceOf(address(TRSRY)),
      user1DaiBalance + user2DaiBalance + user3DaiBalance
    );
  }

  function testCorrectness_RemoveReserveAsset() public {
    vm.prank(godmode);
    TRSRY.removeReserveAsset(DAI);

    assertFalse(TRSRY.isReserveAsset(DAI));
  }

  function testCorrectness_AddReserveAsset() public {
    vm.startPrank(godmode);

    MockERC20 token = new MockERC20("TEST", "TEST", 18);
    TRSRY.addReserveAsset(token);

    assertTrue(TRSRY.isReserveAsset(token));
    vm.stopPrank();
  }

  function testCorrectness_GetReserveAssets() public {
    vm.prank(godmode);
    TRSRY.removeReserveAsset(DAI);

    ERC20[] memory assets = TRSRY.getReserveAssets();

    // ensure there is only one approved asset now that DAI was removed
    assertTrue(assets.length == 1);

    // ensure that USDC is the only reserve asset
    assertTrue(address(assets[0]) == address(USDC));
  }

}