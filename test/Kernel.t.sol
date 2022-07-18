import {Test} from "forge-std/Test.sol";
import {UserFactory} from "./utils/UserFactory.sol";
import {MockModule, UpgradedMockModule, InvalidMockModule, MockPolicy} from "./utils/Mocks.sol";
import "../src/Kernel.sol";


// TODO: add event testing

contract KernelTest is Test {

    Kernel kernel;
    MockModule module;
    MockPolicy policy;

    address deployer;
    address multisig;
    address user;
    UserFactory userFactory;

    bytes err;


    function setUp() public {
      userFactory = new UserFactory();
      address[] memory users = userFactory.create(3);
      deployer = users[0];
      multisig = users[1];
      user = users[2];

      vm.startPrank(deployer);
      kernel = new Kernel();
      module = new MockModule(kernel);
      policy = new MockPolicy(kernel);

      vm.stopPrank();
    }

    function testCorrectness_IntializeKernel() public {
      Kernel.Keycode keycode = Kernel.Keycode.wrap(0);
      Kernel.Identity identity = Kernel.Identity.wrap(0);

      assertEq(kernel.admin(), deployer);
      assertEq(kernel.executor(), deployer);

      assertEq(kernel.policyPermissions(policy, keycode, bytes4(0)), false);
      assertEq(address(kernel.getModuleForKeycode(keycode)), address(0));
      assertEq(Kernel.Keycode.unwrap(kernel.getKeycodeForModule(module)), bytes5(0));

      err = abi.encodeWithSignature("Kernel_OnlyExecutor(address)", address(this));
      vm.expectRevert(err);
      kernel.executeAction(Actions.InstallModule, address(module));

      err = abi.encodeWithSignature("Kernel_OnlyAdmin(address)", address(this));
      vm.expectRevert(err);
      kernel.registerIdentity(address(deployer), Kernel.Identity.wrap("executor"));

      err = abi.encodeWithSignature("Kernel_OnlyAdmin(address)", address(this));
      vm.expectRevert(err);
      kernel.revokeIdentity(deployer);
    }

    function testCorrectness_EnsureContract() public {

      kernel.ensureContract(address(kernel)); 

      err = abi.encodeWithSignature("Kernel_InvalidTargetNotAContract(address)", address(deployer));
      vm.expectRevert(err);
      kernel.ensureContract(deployer);

      err = abi.encodeWithSignature("Kernel_InvalidTargetNotAContract(address)", address(0));
      vm.expectRevert(err);
      kernel.ensureContract(address(0));
    }

    function testCorrectness_EnsureValidKeycode() public {

      kernel.ensureValidKeycode(Kernel.Keycode.wrap("VALID")); 

      err = abi.encodeWithSignature("Kernel_InvalidModuleKeycode(bytes5)", Kernel.Keycode.wrap("inval"));
      vm.expectRevert(err);
      kernel.ensureValidKeycode(Kernel.Keycode.wrap("inval"));

      err = abi.encodeWithSignature("Kernel_InvalidModuleKeycode(bytes5)", Kernel.Keycode.wrap(""));
      vm.expectRevert(err);
      kernel.ensureValidKeycode(Kernel.Keycode.wrap(bytes5("")));
    }

    function testCorrectness_EnsureValidIdentity() public {

      kernel.ensureValidIdentity(Kernel.Identity.wrap("valid")); 

      err = abi.encodeWithSignature("Kernel_InvalidIdentity(bytes10)", Kernel.Identity.wrap("invalid_id"));
      vm.expectRevert(err);
      kernel.ensureValidIdentity(Kernel.Identity.wrap("invalid_id"));

      err = abi.encodeWithSignature("Kernel_InvalidIdentity(bytes10)", Kernel.Identity.wrap("INVALID_ID"));
      vm.expectRevert(err);
      kernel.ensureValidIdentity(Kernel.Identity.wrap(bytes10("INVALID_ID")));
    }
    
    function testCorrectness_RegisterIdentity() public {
      err = abi.encodeWithSignature("Kernel_OnlyAdmin(address)", address(this));
      vm.expectRevert(err);
      kernel.registerIdentity(multisig, Kernel.Identity.wrap("tester"));

      vm.startPrank(deployer);
      kernel.registerIdentity(multisig, Kernel.Identity.wrap("tester"));
      assertEq(Kernel.Identity.unwrap(kernel.getIdentityOfAddress(multisig)), "tester");
      assertEq(kernel.getAddressOfIdentity(Kernel.Identity.wrap("tester")), multisig);
    }

    function testCorrectness_RevokeIdentity() public {
      err = abi.encodeWithSignature("Kernel_OnlyAdmin(address)", address(this));
      vm.expectRevert(err);
      kernel.revokeIdentity(deployer);

      vm.startPrank(deployer);
      kernel.registerIdentity(multisig, Kernel.Identity.wrap("tester"));
      assertEq(Kernel.Identity.unwrap(kernel.getIdentityOfAddress(multisig)), "tester");
      assertEq(kernel.getAddressOfIdentity(Kernel.Identity.wrap("tester")), multisig);

      kernel.revokeIdentity(multisig);
      assertEq(Kernel.Identity.unwrap(kernel.getIdentityOfAddress(multisig)), bytes10(0));
      assertEq(kernel.getAddressOfIdentity(Kernel.Identity.wrap("tester")), address(0));

      err = abi.encodeWithSignature("Kernel_IdentityDoesNotExistForAddress(address)", address(multisig));
      vm.expectRevert(err);
      kernel.revokeIdentity(multisig);
    }

    function testCorrectness_IntializeModule() public {
      assertEq(Kernel.Keycode.unwrap(module.KEYCODE()), "MOCKY");
      assertEq(module.publicState(), 0);
      assertEq(module.permissionedState(), 0);
    }

    function testCorrectness_InstallModule() public {
      vm.startPrank(deployer);

      kernel.executeAction(Actions.InstallModule, address(module));
      assertEq(address(kernel.getModuleForKeycode(Kernel.Keycode.wrap("MOCKY"))), address(module));
      assertEq(Kernel.Keycode.unwrap(kernel.getKeycodeForModule(module)), "MOCKY");

      err = abi.encodeWithSignature("Kernel_InvalidTargetNotAContract(address)", deployer);
      vm.expectRevert(err);
      kernel.executeAction(Actions.InstallModule, deployer);

      Module invalidModule = new InvalidMockModule(kernel);
      err = abi.encodeWithSignature("Kernel_InvalidModuleKeycode(bytes5)", Kernel.Keycode.wrap("badkc"));
      vm.expectRevert(err);
      kernel.executeAction(Actions.InstallModule, address(invalidModule));

      err = abi.encodeWithSignature("Kernel_ModuleAlreadyInstalled(address)", address(module));
      vm.expectRevert(err);
      kernel.executeAction(Actions.InstallModule, address(module));

      vm.stopPrank();
    }

    function testCorrectness_IntializePolicy() public {
      err = abi.encodeWithSignature("Policy_OnlyKernel(address)", address(this));
      vm.expectRevert(err);
      policy.setDependencies();

      err = abi.encodeWithSignature("Policy_OnlyKernel(address)", address(this));
      vm.expectRevert(err);
      policy.permissions();
      
      vm.startPrank(address(kernel));

      err = abi.encodeWithSignature("Policy_ModuleDoesNotExist(bytes5)", Kernel.Keycode.wrap("MOCKY"));
      vm.expectRevert(err);
      policy.setDependencies();

      assertEq(Kernel.Keycode.unwrap(policy.permissions()[0].keycode), "MOCKY");
      assertEq(policy.permissions()[0].funcSelector, module.permissionedCall.selector);

      vm.stopPrank();
    }

    function testCorrectness_ApprovePolicy() public {
      vm.startPrank(deployer);
      
      err = abi.encodeWithSignature("Policy_ModuleDoesNotExist(bytes5)", Kernel.Keycode.wrap("MOCKY"));
      vm.expectRevert(err);
      kernel.executeAction(Actions.ApprovePolicy, address(policy));

      kernel.executeAction(Actions.InstallModule, address(module));
      kernel.executeAction(Actions.ApprovePolicy, address(policy));

      assertEq(kernel.policyPermissions(policy, Kernel.Keycode.wrap("MOCKY"), module.permissionedCall.selector), true);
      assertEq(address(kernel.allPolicies(0)), address(policy));
      assertEq(policy.hasDependency(Kernel.Keycode.wrap("MOCKY")), true);

      policy.callPublicFunction();
      assertEq(module.publicState(), 1);

      // test identity-based auth for policy calls

      err = abi.encodeWithSignature("Policy_OnlyIdentity(bytes10)", Kernel.Identity.wrap("tester"));
      vm.expectRevert(err);
      policy.callPermissionedFunction();

      kernel.registerIdentity(multisig, Kernel.Identity.wrap("tester"));
      vm.stopPrank();

      vm.prank(multisig);
      policy.callPermissionedFunction();
      assertEq(module.permissionedState(), 1);

      vm.prank(deployer);
      kernel.revokeIdentity(multisig);

      vm.prank(multisig);
      err = abi.encodeWithSignature("Policy_OnlyIdentity(bytes10)", Kernel.Identity.wrap("tester"));
      vm.expectRevert(err);
      policy.callPermissionedFunction();
    }

    function testCorrectness_TerminatePolicy() public {
      vm.startPrank(deployer);

      kernel.executeAction(Actions.InstallModule, address(module));
      kernel.executeAction(Actions.ApprovePolicy, address(policy));

      kernel.registerIdentity(multisig, Kernel.Identity.wrap("tester"));

      err = abi.encodeWithSignature("Kernel_PolicyAlreadyApproved(address)", address(policy));
      vm.expectRevert(err);
      kernel.executeAction(Actions.ApprovePolicy, address(policy));

      kernel.executeAction(Actions.TerminatePolicy, address(policy));
      vm.stopPrank();


      vm.prank(multisig);
      err = abi.encodeWithSignature("Module_PolicyNotAuthorized(address)", address(policy));
      vm.expectRevert(err);
      policy.callPermissionedFunction();

      assertEq(kernel.policyPermissions(policy, Kernel.Keycode.wrap("MOCKY"), module.permissionedCall.selector), false);
      vm.expectRevert();
      assertEq(address(kernel.allPolicies(0)), address(0));    
    }

  function testCorrectness_UpgradeModule() public {
      UpgradedMockModule upgradedModule = new UpgradedMockModule(kernel, module);

      vm.startPrank(deployer);

      err = abi.encodeWithSignature("Kernel_ModuleDoesNotExistForKeycode(bytes5)", Kernel.Keycode.wrap("MOCKY"));
      vm.expectRevert(err);
      kernel.executeAction(Actions.UpgradeModule, address(upgradedModule));

      kernel.executeAction(Actions.InstallModule, address(module));
      err = abi.encodeWithSignature("Kernel_ModuleAlreadyInstalled(address)", address(module));
      vm.expectRevert(err);
      kernel.executeAction(Actions.UpgradeModule, address(module));

      kernel.executeAction(Actions.ApprovePolicy, address(policy));
      kernel.registerIdentity(multisig, Kernel.Identity.wrap("tester"));
      
      vm.stopPrank();

      vm.prank(multisig);
      policy.callPermissionedFunction();

      assertEq(module.permissionedState(), 1);
      
      vm.prank(deployer);

      // upgrade module      
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
          kernel.executeAction(Actions.InstallModule, address(module));
          kernel.executeAction(Actions.ApprovePolicy, address(policy));
          kernel.executeAction(Actions.ChangeAdmin, address(multisig));
          vm.stopPrank();
        }

        vm.prank(multisig);

        kernel.registerIdentity(user, Kernel.Identity.wrap("tester"));
        vm.prank(user);
        policy.callPermissionedFunction();

        vm.prank(deployer);
        kernel.executeAction(Actions.ChangeAdmin, address(user));

        vm.startPrank(multisig);
        err = abi.encodeWithSignature("Kernel_OnlyAdmin(address)", multisig);
        vm.expectRevert(err);
        kernel.registerIdentity(multisig, Kernel.Identity.wrap("tester"));
        vm.stopPrank();

        vm.prank(user);
        kernel.revokeIdentity(user);
        assertEq(Kernel.Identity.unwrap(kernel.getIdentityOfAddress(user)), bytes10(0));
        assertEq(kernel.getAddressOfIdentity(Kernel.Identity.wrap("tester")), address(0));  
        
        err = abi.encodeWithSignature("Policy_OnlyIdentity(bytes10)", Kernel.Identity.wrap("tester"));
        vm.expectRevert(err);
        vm.prank(user);
        policy.callPermissionedFunction();
    }
}
