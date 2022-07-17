// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

// ######################## ~ ERRORS ~ ########################

// MODULE

error Module_PolicyNotAuthorized();

// POLICY

error Policy_ModuleDoesNotExist(Kernel.Keycode keycode_);
error Policy_OnlyKernel(address caller_);
error Policy_OnlyIdentity(Kernel.Identity identity_);

// KERNEL

error Kernel_OnlyExecutor(address caller_);
error Kernel_OnlyAdmin(address caller_);
error Kernel_IdentityAlreadyExists(Kernel.Identity identity_);
error Kernel_InvalidIdentity(Kernel.Identity identity_);
error Kernel_InvalidTargetNotAContract(address target_);
error Kernel_ModuleAlreadyInstalled(Kernel.Keycode module_);
error Kernel_ModuleAlreadyExists(Kernel.Keycode module_);
error Kernel_InvalidModuleKeycode(Kernel.Keycode module_);
error Kernel_PolicyAlreadyApproved(address policy_);
error Kernel_PolicyNotApproved(address policy_);

// ######################## ~ GLOBAL TYPES ~ ########################

enum Actions {
    InstallModule,
    UpgradeModule,
    ApprovePolicy,
    TerminatePolicy,
    ChangeExecutor,
    ChangeAdmin
}

struct Instruction {
    Actions action;
    address target;
}

struct RequestPermissions {
    Kernel.Keycode keycode;
    bytes4 funcSelector;
}

// ######################## ~ MODULE ABSTRACT ~ ########################

abstract contract Module {
    Kernel public kernel;

    constructor(Kernel kernel_) {
        kernel = kernel_;
    }

    modifier permissioned() {
      Kernel.Keycode keycode = KEYCODE();
      if (kernel.policyPermissions(Policy(msg.sender), keycode, msg.sig) == false) {
        revert Module_PolicyNotAuthorized();
      }
      _;
    }

    function KEYCODE() public pure virtual returns (Kernel.Keycode);

    /// @notice Specify which version of a module is being implemented.
    /// @dev Minor version change retains interface. Major version upgrade indicates
    ///      breaking change to the interface.
    function VERSION()
        external
        pure
        virtual
        returns (uint8 major, uint8 minor)
    {}
}

abstract contract Policy {
    Kernel public kernel;
    
    mapping(Kernel.Keycode => bool) public hasDependency;


    constructor(Kernel kernel_) {
        kernel = kernel_;
    }

    modifier onlyKernel() {
        if (msg.sender != address(kernel)) revert Policy_OnlyKernel(msg.sender);
        _;
    }

    modifier onlyIdentity(Kernel.Identity identity_) {
        if(Kernel.Identity.unwrap(kernel.getIdentityOfAddress(msg.sender)) != Kernel.Identity.unwrap(identity_)) revert Policy_OnlyIdentity(identity_);
        _;
    }

    function keycode(bytes5 keycode_) internal pure returns (Kernel.Keycode keycode) {
        keycode = Kernel.Keycode.wrap(keycode_);
    }

    function registerDependency(Kernel.Keycode keycode_) 
      external 
      onlyKernel  
    {
        hasDependency[keycode_] = true;
    }

    function updateDependencies() 
      external 
      virtual 
      onlyKernel 
      returns (Kernel.Keycode[] memory dependencies) 
    {}

    function requestPermissions()
        external
        view
        virtual
        returns (RequestPermissions[] memory requests)
    {}

    function getModuleAddress(Kernel.Keycode keycode_) internal view returns (address) {
        address moduleAddress = address(kernel.getModuleForKeycode(keycode_));

        if (moduleAddress == address(0))
            revert Policy_ModuleDoesNotExist(keycode_);

        return moduleAddress;
    }
}

contract Kernel {
    // ######################## ~ VARS ~ ########################

    type Keycode is bytes5;
    type Identity is bytes10;
    address public executor;
    address public admin;

    // ######################## ~ DEPENDENCY MANAGEMENT ~ ########################

    mapping(Policy => mapping(Keycode => mapping(bytes4 => bool))) public policyPermissions; // for policy addr, check if they have permission to call the function
    Policy[] public allPolicies; // all the approved policies in the kernel

    mapping(Keycode => Module) public getModuleForKeycode; // get contract for module keycode
    mapping(Module => Keycode) public getKeycodeForModule; // get module keycode for contract
    
    mapping(address => Identity) public getIdentityOfAddress;
    mapping(Identity => address) public getAddressOfIdentity;


    // ######################## ~ EVENTS ~ ########################

    event PermissionsUpated(
        Policy indexed policy_,
        Keycode indexed keycode_,
        bytes4 indexed funcSelector_,
        bool granted_
    );

    event ActionExecuted(Actions indexed action_, address indexed target_);

    // ######################## ~ BODY ~ ########################

    constructor() {
        executor = msg.sender;
        admin = msg.sender;
    }

    // ######################## ~ MODIFIERS ~ ########################

    modifier onlyExecutor() {
        if (msg.sender != executor) revert Kernel_OnlyExecutor(msg.sender);
        _;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Kernel_OnlyAdmin(msg.sender);
        _;
    }

    // ######################## ~ KERNEL INTERFACE ~ ########################

    function ensureContract(address target_) public view {
        uint256 size;
        assembly {
            size := extcodesize(target_)
        }
        if (size == 0) revert Kernel_InvalidTargetNotAContract(target_);
    }

    function ensureValidKeycode(Kernel.Keycode keycode_) public pure {
        bytes5 unwrapped = Kernel.Keycode.unwrap(keycode_);

        for (uint256 i = 0; i < 5; ) {
            bytes1 char = unwrapped[i];

            if (char < 0x41 || char > 0x5A) revert Kernel_InvalidModuleKeycode(keycode_); // A-Z only"

            unchecked { i++; }
        }
    }

    function ensureValidIdentity(Kernel.Identity identity_) public pure {
        bytes10 unwrapped = Kernel.Identity.unwrap(identity_);

        for (uint256 i = 0; i < 10; ) {
            bytes1 char = unwrapped[i];
            if (!(char >= 0x61 && char <= 0x7A)) {
              revert Kernel_InvalidIdentity(identity_);  // a-z only
            }
            unchecked { i++; }
        }
    }

    function toKeycode(bytes5 keycode_) public pure returns (Kernel.Keycode keycode) {
        keycode = Kernel.Keycode.wrap(keycode_);
    }

    function fromKeycode(Keycode keycode_) public pure returns (bytes5 keycode) {
        keycode = Keycode.unwrap(keycode_);
    }

    function toIdentity(bytes5 identity_) public pure returns (Identity identity) {
        identity = Identity.wrap(identity_);
    }

    function fromidentity(Identity identity_) public pure returns (bytes10 identity) {
        identity = Identity.unwrap(identity_);
    }


    function registerIdentity(address address_, Identity identity_)
      external
      onlyAdmin
    {
      if (Identity.unwrap(getIdentityOfAddress[address_]) != bytes10(0) ) revert Kernel_IdentityAlreadyExists(identity_);
      ensureValidIdentity(identity_);

      getIdentityOfAddress[address_] = identity_;
      getAddressOfIdentity[identity_] = address_;
    }


    function revokeIdentity(Identity identity_)
      external
      onlyAdmin
    {
      address addressOfIdentity = getAddressOfIdentity[identity_];
      if (addressOfIdentity == address(0)) revert Kernel_IdentityAlreadyExists(identity_);
      getAddressOfIdentity[identity_] = address(0);
      getIdentityOfAddress[addressOfIdentity] = Identity.wrap(bytes10(0));
    }


    function executeAction(Actions action_, address target_)
        external
        onlyExecutor
    {
        if (action_ == Actions.InstallModule) {
            ensureContract(target_);
            ensureValidKeycode(Module(target_).KEYCODE());
            _installModule(Module(target_));
        } else if (action_ == Actions.UpgradeModule) {
            ensureContract(target_);
            ensureValidKeycode(Module(target_).KEYCODE());
            _upgradeModule(Module(target_));
        } else if (action_ == Actions.ApprovePolicy) {
            ensureContract(target_);
            _approvePolicy(Policy(target_));
        } else if (action_ == Actions.TerminatePolicy) {
            ensureContract(target_);
            _terminatePolicy(Policy(target_));
        } else if (action_ == Actions.ChangeExecutor) {
            executor = target_;
        } else if (action_ == Actions.ChangeAdmin) {
            admin = target_;
        }

        emit ActionExecuted(action_, target_);
    }

    // ######################## ~ KERNEL INTERNAL ~ ########################

    function _installModule(Module newModule_) internal {
        Keycode keycode = Module(newModule_).KEYCODE();

        // @NOTE check newModule_ != 0
        if (address(getModuleForKeycode[keycode]) != address(0))
            revert Kernel_ModuleAlreadyInstalled(keycode);

        getModuleForKeycode[keycode] = newModule_;
        getKeycodeForModule[newModule_] = keycode;
    }

    function _upgradeModule(Module newModule_) internal {
        Keycode keycode = newModule_.KEYCODE();
        Module oldModule = getModuleForKeycode[keycode];

        if (address(oldModule) == address(0) || address(oldModule) == address(newModule_))
            revert Kernel_ModuleAlreadyExists(keycode);

        getKeycodeForModule[oldModule] = Keycode.wrap(bytes5(0));
        getKeycodeForModule[newModule_] = keycode;
        getModuleForKeycode[keycode] = newModule_;

        // go through each policy in the Kernel and update its dependencies if they include the module
        for (uint i; i < allPolicies.length; ) {
            Policy policy = allPolicies[i];
            if (policy.hasDependency(keycode)) {
                policy.updateDependencies();
            }
        }
    }

    function _approvePolicy(Policy policy_) internal {
        policy_.updateDependencies();
        RequestPermissions[] memory requests = policy_.requestPermissions();
        
        for (uint256 i = 0; i < requests.length; ) {
            RequestPermissions memory request = requests[i];

            policyPermissions[policy_][request.keycode][request.funcSelector] = true;

            policy_.registerDependency(request.keycode);

            emit PermissionsUpated(policy_, request.keycode, request.funcSelector, true);

            unchecked { i++; }

        }

        allPolicies.push(policy_);
    }

    function _terminatePolicy(Policy policy_) internal {

        RequestPermissions[] memory requests = Policy(policy_).requestPermissions();

        for (uint256 i = 0; i < requests.length; ) {
            RequestPermissions memory request = requests[i];

            policyPermissions[policy_][request.keycode][request.funcSelector] = false;

            emit PermissionsUpated(policy_, request.keycode, request.funcSelector, false);

            unchecked { i++; }
        }

        // swap the current policy (terminated) with the last policy in the list and remove the last item
        uint numPolicies = allPolicies.length;

        for (uint j; j < numPolicies;) {
            if (allPolicies[j] == policy_) {
              allPolicies[j] = allPolicies[numPolicies - 1]; 
              allPolicies.pop();
            }
        }
    }
}