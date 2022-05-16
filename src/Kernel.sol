// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

abstract contract Module {
    error Module_OnlyApprovedPolicy(address caller_);
    error Module_OnlyPermissionedPolicy(address caller_);

    IKernel public _kernel;

    constructor(IKernel kernel_) {
        _kernel = kernel_;
    }

    function KEYCODE() public pure virtual returns (bytes5) {}

    modifier onlyPermitted() {
        if (_kernel.getWritePermissions(KEYCODE(), msg.sender) == false)
            revert Module_OnlyPermissionedPolicy(msg.sender);
        _;
    }
}

abstract contract Policy {
    error Policy_ModuleDoesNotExist(bytes5 keycode_);
    error Policy_OnlyKernel(address caller_);

    IKernel public _kernel;

    constructor(IKernel kernel_) {
        _kernel = kernel_;
    }

    function getModuleAddress(bytes5 keycode_) internal view returns (address) {
        address moduleForKeycode = _kernel.getModuleForKeycode(keycode_);

        if (moduleForKeycode == address(0))
            revert Policy_ModuleDoesNotExist(keycode_);

        return moduleForKeycode;
    }

    function configureReads() external virtual onlyKernel {}

    function requestWrites()
        external
        view
        virtual
        onlyKernel
        returns (bytes5[] memory permissions)
    {}

    modifier onlyKernel() {
        if (msg.sender != address(_kernel))
            revert Policy_OnlyKernel(msg.sender);
        _;
    }
}

enum Actions {
    InstallModule,
    UpgradeModule,
    ApprovePolicy,
    TerminatePolicy,
    ChangeExecutor
}

struct Instruction {
    Actions action;
    address target;
}

// Core kernel functions for modules and policies to work
interface IKernel {
    function getWritePermissions(bytes5 keycode_, address caller_)
        external
        view
        returns (bool);

    function getModuleForKeycode(bytes5 keycode_)
        external
        view
        returns (address);

    function executeAction(Actions action_, address target_) external;
}

contract Kernel is IKernel {
    event Kernel_WritePermissionsUpdated(
        bytes5 indexed keycode_,
        address indexed policy_,
        bool enabled_
    );

    error Kernel_OnlyExecutor(address caller_);
    error Kernel_ModuleAlreadyInstalled(bytes5 module_);
    error Kernel_ModuleAlreadyExists(bytes5 module_);
    error Kernel_PolicyAlreadyApproved(address policy_);
    error Kernel_PolicyNotApproved(address policy_);

    address public executor;

    constructor() {
        executor = msg.sender;
    }

    modifier onlyExecutor() {
        if (msg.sender != executor) revert Kernel_OnlyExecutor(msg.sender);
        _;
    }

    ///////////////////////////////////////////////////////////////////////////////////////
    //                                 DEPENDENCY MANAGEMENT                             //
    ///////////////////////////////////////////////////////////////////////////////////////

    mapping(bytes5 => address) public getModuleForKeycode; // get contract for module keycode
    mapping(address => bytes5) public getKeycodeForModule; // get module keycode for contract
    mapping(address => bool) public approvedPolicies; // whitelisted apps
    mapping(bytes5 => mapping(address => bool)) public getWritePermissions; // can module (bytes5) be written to by policy (address)
    address[] public allPolicies;

    event ActionExecuted(Actions action_, address target_);

    function executeAction(Actions action_, address target_)
        external
        onlyExecutor
    {
        if (action_ == Actions.InstallModule) {
            _installModule(target_);
        } else if (action_ == Actions.UpgradeModule) {
            _upgradeModule(target_);
        } else if (action_ == Actions.ApprovePolicy) {
            _approvePolicy(target_);
        } else if (action_ == Actions.TerminatePolicy) {
            _terminatePolicy(target_);
        } else if (action_ == Actions.ChangeExecutor) {
            // Require kernel to install the EXCTR module before calling ChangeExecutor on it
            if (getKeycodeForModule[target_] != "EXCTR")
                revert Kernel_OnlyExecutor(target_);

            executor = target_;
        }

        emit ActionExecuted(action_, target_);
    }

    function _installModule(address newModule_) internal {
        bytes5 keycode = Module(newModule_).KEYCODE();

        // @NOTE check newModule_ != 0
        if (getModuleForKeycode[keycode] != address(0))
            revert Kernel_ModuleAlreadyInstalled(keycode);

        getModuleForKeycode[keycode] = newModule_;
        getKeycodeForModule[newModule_] = keycode;
    }

    function _upgradeModule(address newModule_) internal {
        bytes5 keycode = Module(newModule_).KEYCODE();
        address oldModule = getModuleForKeycode[keycode];

        if (oldModule == address(0) || oldModule == newModule_)
            revert Kernel_ModuleAlreadyExists(keycode);

        getKeycodeForModule[oldModule] = bytes5(0);
        getKeycodeForModule[newModule_] = keycode;
        getModuleForKeycode[keycode] = newModule_;

        _reconfigurePolicies();
    }

    function _approvePolicy(address policy_) internal {
        if (approvedPolicies[policy_] == true)
            revert Kernel_PolicyAlreadyApproved(policy_);

        approvedPolicies[policy_] = true;

        Policy(policy_).configureReads();

        bytes5[] memory permissions = Policy(policy_).requestWrites();
        _setWritePermissions(policy_, permissions, true);

        allPolicies.push(policy_);
    }

    function _terminatePolicy(address policy_) internal {
        if (approvedPolicies[policy_] == false)
            revert Kernel_PolicyNotApproved(policy_);

        approvedPolicies[policy_] = false;

        bytes5[] memory permissions = Policy(policy_).requestWrites();
        _setWritePermissions(policy_, permissions, false);
    }

    function _reconfigurePolicies() internal {
        for (uint256 i = 0; i < allPolicies.length; i++) {
            address policy_ = allPolicies[i];

            if (approvedPolicies[policy_] == true)
                Policy(policy_).configureReads();
        }
    }

    function _setWritePermissions(
        address policy_,
        bytes5[] memory keycodes_,
        bool canWrite_
    ) internal {
        for (uint256 i = 0; i < keycodes_.length; i++) {
            getWritePermissions[keycodes_[i]][policy_] = canWrite_;
            emit Kernel_WritePermissionsUpdated(
                keycodes_[i],
                policy_,
                canWrite_
            );
        }
    }
}
