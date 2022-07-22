// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {UserFactory} from "test-utils/UserFactory.sol";
import "./mocks/KernelTestMocks.sol";
import "src/Kernel.sol";

contract KernelTest is Test {
    Kernel internal kernel;
    MockPolicy internal policy;
    MockModule internal MOCKY;

    address public deployer;
    address public multisig;
    address public user;
    UserFactory public userFactory;

    bytes public err;
    MockPolicy internal policyTest;

    function setUp() public {
      userFactory = new UserFactory();
      address[] memory users = userFactory.create(3);
      deployer = users[0];
      multisig = users[1];
      user = users[2];

      vm.startPrank(deployer);
      kernel = new Kernel();
      MOCKY = new MockModule(kernel);
      policy = new MockPolicy(kernel);

      vm.stopPrank();
    }

    function testCorrectness_InitializeKernel() public {
      Keycode keycode = Keycode.wrap(0);
      Role role = Role.wrap(0);

      assertEq(kernel.admin(), deployer);
      assertEq(kernel.executor(), deployer);
      assertEq(kernel.policyPermissions(policy, keycode, bytes4(0)), false);
      assertEq(address(kernel.getModuleForKeycode(keycode)), address(0));
      assertEq(Keycode.unwrap(kernel.getKeycodeForModule(MOCKY)), bytes5(0));

      // Ensure actions cannot be performed by unauthorized addresses
      err = abi.encodeWithSignature("Kernel_OnlyExecutor(address)", address(this));
      vm.expectRevert(err);
      kernel.executeAction(Actions.InstallModule, address(MOCKY));

      err = abi.encodeWithSignature("Kernel_OnlyAdmin(address)", address(this));
      vm.expectRevert(err);
      kernel.registerRole(address(deployer), Role.wrap("executor"));

      err = abi.encodeWithSignature("Kernel_OnlyAdmin(address)", address(this));
      vm.expectRevert(err);
      kernel.revokeRole(deployer);
    }

    function testCorrectness_EnsureContract() public {

      ensureContract(address(kernel)); 

      err = abi.encodeWithSignature("TargetNotAContract(address)", address(deployer));
      vm.expectRevert(err);
      ensureContract(deployer);

      err = abi.encodeWithSignature("TargetNotAContract(address)", address(0));
      vm.expectRevert(err);
      ensureContract(address(0));
    }

    function testCorrectness_EnsureValidKeycode() public {

      ensureValidKeycode(Keycode.wrap("VALID")); 

      err = abi.encodeWithSignature("InvalidKeycode(bytes5)", Keycode.wrap("inval"));
      vm.expectRevert(err);
      ensureValidKeycode(Keycode.wrap("inval"));

      err = abi.encodeWithSignature("InvalidKeycode(bytes5)", Keycode.wrap(""));
      vm.expectRevert(err);
      ensureValidKeycode(Keycode.wrap(bytes5("")));
    }

    function testCorrectness_EnsureValidRole() public {

      ensureValidRole(Role.wrap("valid")); 

      err = abi.encodeWithSignature("InvalidRole(bytes32)", Role.wrap("invalid_id"));
      vm.expectRevert(err);
      ensureValidRole(Role.wrap("invalid_id"));

      err = abi.encodeWithSignature("InvalidIdentity(bytes32)", Role.wrap("INVALID_ID"));
      vm.expectRevert(err);
      ensureValidRole(Role.wrap(bytes32("INVALID_ID")));
    }
    
    function testCorrectness_RegisterRole() public {
      err = abi.encodeWithSignature("Kernel_OnlyAdmin(address)", address(this));
      vm.expectRevert(err);
      kernel.registerRole(multisig, Role.wrap("tester"));

      vm.prank(deployer);
      kernel.registerRole(multisig, Role.wrap("tester"));
      assertEq(Role.unwrap(kernel.getRoleOfAddress(multisig)), "tester");
      assertEq(kernel.getAddressOfRole(Role.wrap("tester")), multisig);
    }

    function testCorrectness_RevokeRole() public {
      err = abi.encodeWithSignature("Kernel_OnlyAdmin(address)", address(this));
      vm.expectRevert(err);
      kernel.revokeRole(deployer);

      vm.startPrank(deployer);
      kernel.registerRole(multisig, Role.wrap("tester"));
      assertEq(Role.unwrap(kernel.getRoleOfAddress(multisig)), "tester");
      assertEq(kernel.getAddressOfRole(Role.wrap("tester")), multisig);

      kernel.revokeRole(multisig);
      assertEq(Role.unwrap(kernel.getRoleOfAddress(multisig)), bytes10(0));
      assertEq(kernel.getAddressOfRole(Role.wrap("tester")), address(0));

      err = abi.encodeWithSignature("Kernel_RoleDoesNotExistForAddress(address)", address(multisig));
      vm.expectRevert(err);
      kernel.revokeRole(multisig);
    }

    function testCorrectness_InitializeModule() public {
      assertEq(Keycode.unwrap(MOCKY.KEYCODE()), "MOCKY");
      assertEq(MOCKY.publicState(), 0);
      assertEq(MOCKY.permissionedState(), 0);
    }

    function testCorrectness_InstallModule() public {
      vm.startPrank(deployer);

      // Ensure module is installed properly
      kernel.executeAction(Actions.InstallModule, address(MOCKY));
      assertEq(address(kernel.getModuleForKeycode(Keycode.wrap("MOCKY"))), address(MOCKY));
      assertEq(Keycode.unwrap(kernel.getKeycodeForModule(MOCKY)), "MOCKY");

      // Try installing an EOA as a module
      err = abi.encodeWithSignature("TargetNotAContract(address)", deployer);
      vm.expectRevert(err);
      kernel.executeAction(Actions.InstallModule, deployer);

      // Try installing module with a bad keycode
      Module invalidModule = new InvalidMockModule(kernel);
      err = abi.encodeWithSignature("InvalidKeycode(bytes5)", Keycode.wrap("badkc"));
      vm.expectRevert(err);
      kernel.executeAction(Actions.InstallModule, address(invalidModule));

      // Try installing MOCKY again
      err = abi.encodeWithSignature("Kernel_ModuleAlreadyInstalled(bytes5)", Keycode.wrap("MOCKY"));
      vm.expectRevert(err);
      kernel.executeAction(Actions.InstallModule, address(MOCKY));

      vm.stopPrank();
    }

    // TODO Move to bottom or separate file
    function _approveTestPolicy() internal {
      vm.startPrank(deployer);
      kernel.executeAction(Actions.InstallModule, address(MOCKY));
      kernel.executeAction(Actions.ApprovePolicy, address(policy));
      vm.stopPrank();
    }

    function testCorrectness_ApprovePolicy() public {
      Keycode testKeycode = Keycode.wrap("MOCKY");

      vm.prank(deployer);
      err = abi.encodeWithSignature("Policy_ModuleDoesNotExist(bytes5)", testKeycode);
      vm.expectRevert(err);
      kernel.executeAction(Actions.ApprovePolicy, address(policy));

      _approveTestPolicy();

      assertEq(kernel.policyPermissions(policy, testKeycode, MOCKY.permissionedCall.selector), true);
      assertEq(address(kernel.allPolicies(0)), address(policy));

      uint256 depIndex = kernel.getDependentIndex(testKeycode, policy);
      Policy[] memory dependencies = new Policy[](1);
      dependencies[0] = policy;
      assertEq(address(kernel.moduleDependents(testKeycode, depIndex)), address(dependencies[0]));

      vm.prank(deployer);
      err = abi.encodeWithSignature("Kernel_PolicyAlreadyApproved(address)", address(policy));
      vm.expectRevert(err);
      kernel.executeAction(Actions.ApprovePolicy, address(policy));
    }

    function testCorrectness_PolicyPermissions() public {
      Permissions[] memory permissions = policy.requestPermissions();

      assertEq(Keycode.unwrap(permissions[0].keycode), "MOCKY");
      assertEq(permissions[0].funcSelector, MOCKY.permissionedCall.selector);
    }

    function testCorrectness_CallPublicPolicyFunction() public {
      _approveTestPolicy();

      vm.prank(deployer);
      policy.callPublicFunction();

      assertEq(MOCKY.publicState(), 1);
    }

    function testCorrectness_CallPermissionedPolicyFunction() public {
      _approveTestPolicy();

      // Test role-based auth for policy calls
      Role testerRole = Role.wrap("tester");

      vm.startPrank(deployer);
      err = abi.encodeWithSignature("Policy_OnlyRole(bytes32)", testerRole);
      vm.expectRevert(err);
      policy.callPermissionedFunction();

      kernel.registerRole(multisig, testerRole);
      vm.stopPrank();

      vm.prank(multisig);
      policy.callPermissionedFunction();
      assertEq(MOCKY.permissionedState(), 1);

      vm.prank(deployer);
      kernel.revokeRole(multisig);

      vm.prank(multisig);
      err = abi.encodeWithSignature("Policy_OnlyRole(bytes32)", testerRole);
      vm.expectRevert(err);
      policy.callPermissionedFunction();
    }

    function testCorrectness_TerminatePolicy() public {
      vm.startPrank(deployer);

      kernel.executeAction(Actions.InstallModule, address(MOCKY));
      kernel.executeAction(Actions.ApprovePolicy, address(policy));

      kernel.registerRole(multisig, Role.wrap("tester"));

      err = abi.encodeWithSignature("Kernel_PolicyAlreadyApproved(address)", address(policy));
      vm.expectRevert(err);
      kernel.executeAction(Actions.ApprovePolicy, address(policy));

      kernel.executeAction(Actions.TerminatePolicy, address(policy));
      vm.stopPrank();

      vm.prank(multisig);
      err = abi.encodeWithSignature("Module_PolicyNotAuthorized(address)", address(policy));
      vm.expectRevert(err);
      policy.callPermissionedFunction();

      assertEq(kernel.policyPermissions(policy, Keycode.wrap("MOCKY"), MOCKY.permissionedCall.selector), false);
      vm.expectRevert();
      assertEq(address(kernel.allPolicies(0)), address(0));    
    }

  function testCorrectness_UpgradeModule() public {
      UpgradedMockModule upgradedModule = new UpgradedMockModule(kernel, MOCKY);

      vm.startPrank(deployer);

      err = abi.encodeWithSignature("Kernel_ModuleDoesNotExistForKeycode(bytes5)", Keycode.wrap("MOCKY"));
      vm.expectRevert(err);
      kernel.executeAction(Actions.UpgradeModule, address(upgradedModule));

      kernel.executeAction(Actions.InstallModule, address(MOCKY));
      err = abi.encodeWithSignature("Kernel_ModuleAlreadyInstalled(address)", address(MOCKY));
      vm.expectRevert(err);
      kernel.executeAction(Actions.UpgradeModule, address(MOCKY));

      kernel.executeAction(Actions.ApprovePolicy, address(policy));
      kernel.registerRole(multisig, Role.wrap("tester"));
      
      vm.stopPrank();

      vm.prank(multisig);
      policy.callPermissionedFunction();

      assertEq(MOCKY.permissionedState(), 1);
      
      vm.prank(deployer);

      // upgrade MOCKY      
      kernel.executeAction(Actions.UpgradeModule, address(upgradedModule));

      // check state is reset
      assertEq(upgradedModule.permissionedState(), 1);

      // check if permissions persist
      vm.prank(multisig);
      policy.callPermissionedFunction();

      assertEq(upgradedModule.permissionedState(), 2);      
  }

  function testCorrectness_ChangeExecutor() public {

      vm.startPrank(deployer);
      kernel.executeAction(Actions.ChangeExecutor, address(multisig));

      err = abi.encodeWithSignature("Kernel_OnlyExecutor(address)", deployer);
      vm.expectRevert(err);
      kernel.executeAction(Actions.ChangeExecutor, address(deployer));

      vm.stopPrank();

      vm.prank(multisig);
      kernel.executeAction(Actions.ChangeExecutor, address(deployer));

      vm.startPrank(deployer);
      kernel.executeAction(Actions.ChangeExecutor, address(multisig));
    }

    function testCorrectness_ChangeAdmin() public {

        err = abi.encodeWithSignature("Kernel_OnlyExecutor(address)", address(this));
        vm.expectRevert(err);
        kernel.executeAction(Actions.ChangeAdmin, address(multisig));

        vm.startPrank(deployer);
        
        {
          kernel.executeAction(Actions.InstallModule, address(MOCKY));
          kernel.executeAction(Actions.ApprovePolicy, address(policy));
          kernel.executeAction(Actions.ChangeAdmin, address(multisig));
          vm.stopPrank();
        }

        vm.prank(multisig);

        kernel.registerRole(user, Role.wrap("tester"));
        vm.prank(user);
        policy.callPermissionedFunction();

        vm.prank(deployer);
        kernel.executeAction(Actions.ChangeAdmin, address(user));

        vm.startPrank(multisig);
        err = abi.encodeWithSignature("Kernel_OnlyAdmin(address)", multisig);
        vm.expectRevert(err);
        kernel.registerRole(multisig, Role.wrap("tester"));
        vm.stopPrank();

        vm.prank(user);
        kernel.revokeRole(user);
        assertEq(Role.unwrap(kernel.getRoleOfAddress(user)), bytes10(0));
        assertEq(kernel.getAddressOfRole(Role.wrap("tester")), address(0));  
        
        err = abi.encodeWithSignature("Policy_OnlyIdentity(bytes10)", Role.wrap("tester"));
        vm.expectRevert(err);
        vm.prank(user);
        policy.callPermissionedFunction();
    }
}