// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

//import {Test} from "forge-std/Test.sol";
import { PRBTest } from "prb-test/PRBTest.sol";

import {MockModule, MockPolicy} from "./mocks/MockPolicyModule.sol";
import {UserFactory} from "./utils/UserFactory.sol";
import "src/Kernel.sol";
//import {MockModule} from "./mocks/MockModule.sol";
//import {MockPolicy} from "./mocks/MockPolicy.sol";

contract KernelTest is PRBTest {
    Kernel internal kernel;
    MockPolicy internal mockPolicy;
    MockModule internal MOCKY;

    address deployer;
    address multisig;
    address user;
    UserFactory userFactory;

    bytes err;

    MockPolicy internal policyTest;

    function setUp() public {
        kernel = new Kernel();
        //userCreater = new users(1);

        mockPolicy = new MockPolicy(kernel);
        MOCKY = new MockModule(kernel);

        kernel.executeAction(Actions.InstallModule, address(MOCKY));
        kernel.executeAction(Actions.ApprovePolicy, address(mockPolicy));

        // For approve policy test
        policyTest = new MockPolicy(kernel);
    }

    function testGas_ApprovePolicy() public {
        //MockPolicy policyTest = new MockPolicy(kernel);
        kernel.executeAction(Actions.ApprovePolicy, address(policyTest));
    }

    function testGas_CallPublic() public {
        mockPolicy.callPublicFunction();
    }

    function testGas_CallPermissioned() public {
        mockPolicy.callPermissionedFunction();
    }

    /*
    function test_InstallModule() public {
        address moduleAddr = address(LARPR);

        kernel.executeAction(Actions.InstallModule, moduleAddr);

        assertEq(kernel.getModuleForKeycode("LARPR"), moduleAddr);
        assertEq(kernel.getKeycodeForModule(moduleAddr), "LARPR");

        // TODO Y U NO WORK
        //vm.expectRevert(
        //    abi.encodeWithSelector(
        //        kernel.Kernel_ModuleAlreadyInstalled.selector,
        //        "0x4c41525052"
        //    )
        //);
        //kernel.executeAction(Actions.InstallModule, moduleAddr);
    }

    function test_UpgradeModule() public {
        address moduleAddr1 = address(LARPR);
        LarpModule larprUpgrade = new LarpModule(kernel);
        address moduleAddr2 = address(larprUpgrade);

        kernel.executeAction(Actions.InstallModule, moduleAddr1); // Tested above
        kernel.executeAction(Actions.UpgradeModule, moduleAddr2);

        assertEq(kernel.getModuleForKeycode("LARPR"), moduleAddr2);
        assertEq(kernel.getKeycodeForModule(moduleAddr2), "LARPR");
    }

    function test_ApprovePolicy() public {
        address policyAddr = address(mockPolicy);
        kernel.executeAction(Actions.ApprovePolicy, policyAddr);

        // TODO test policy is added to end of allPolicies
        assertEq(kernel.allPolicies(0), policyAddr);
        assertTrue(kernel.approvedPolicies(policyAddr));
        assertTrue(kernel.getWritePermissions("LARPR", policyAddr));
    }

    function test_TerminatePolicy() public {
        address policyAddr = address(mockPolicy);
        kernel.executeAction(Actions.ApprovePolicy, policyAddr); // Tested above

        kernel.executeAction(Actions.TerminatePolicy, policyAddr);

        assertEq(kernel.allPolicies(0), policyAddr); // Policy does not get deleted from here
        assertFalse(kernel.approvedPolicies(policyAddr));
        assertFalse(kernel.getWritePermissions("LARPR", policyAddr));
    }
    */
}