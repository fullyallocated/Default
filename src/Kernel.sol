// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.13;

// ######################## ~ ERRORS ~ ########################

// MODULE

error Module_PolicyNotAuthorized(Policy policy_);
error Module_OnlyKernel(address caller_);

// POLICY

error Policy_ModuleDoesNotExist(Kernel.Keycode keycode_);
error Policy_OnlyKernel(address caller_);
error Policy_OnlyIdentity(Kernel.Identity identity_);

// KERNEL

error Kernel_OnlyExecutor(address caller_);
error Kernel_OnlyAdmin(address caller_);
error Kernel_AddressAlreadyHasIdentity(address address_);
error Kernel_IdentityDoesNotExistForAddress(address address_);
error Kernel_IdentityAlreadyExistsForAddress(Kernel.Identity identity_);
error Kernel_InvalidIdentity(Kernel.Identity identity_);
error Kernel_InvalidTargetNotAContract(address target_);
error Kernel_ModuleAlreadyInstalled(Module module_);
error Kernel_ModuleDoesNotExistForKeycode(Kernel.Keycode keycode_);
error Kernel_InvalidModuleKeycode(Kernel.Keycode module_);
error Kernel_PolicyAlreadyApproved(Policy policy_);
error Kernel_PolicyNotApproved(Policy policy_);

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
        revert Module_PolicyNotAuthorized(Policy(msg.sender));
      }
      _;
    }

    modifier onlyKernel() {
        if (msg.sender != address(kernel)) revert Module_OnlyKernel(msg.sender);
        _;
    }

    function _toKeycode(bytes5 keycode_) internal pure returns (Kernel.Keycode keycode) {
        keycode = Kernel.Keycode.wrap(keycode_);
    }

    function _fromKeycode(Kernel.Keycode keycode_) internal pure returns (bytes5 keycode) {
        keycode = Kernel.Keycode.unwrap(keycode_);
    }

    function _toIdentity(bytes10 identity_) internal pure returns (Kernel.Identity identity) {
        identity = Kernel.Identity.wrap(identity_);
    }

    function _fromidentity(Kernel.Identity identity_) internal pure returns (bytes10 identity) {
        identity = Kernel.Identity.unwrap(identity_);
    }

    function KEYCODE() public pure virtual returns (Kernel.Keycode) {}

    
    function INIT() public virtual onlyKernel {}

    /// @notice Specify which version of a module is being implemented.
    /// @dev Minor version change retains interface. Major version upgrade indicates
    ///      breaking change to the interface.
    function VERSION() external pure virtual returns (uint8 major, uint8 minor) {}
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

    function _toKeycode(bytes5 keycode_) internal pure returns (Kernel.Keycode keycode) {
        keycode = Kernel.Keycode.wrap(keycode_);
    }

    function _fromKeycode(Kernel.Keycode keycode_) internal pure returns (bytes5 keycode) {
        keycode = Kernel.Keycode.unwrap(keycode_);
    }

    function _toIdentity(bytes10 identity_) internal pure returns (Kernel.Identity identity) {
        identity = Kernel.Identity.wrap(identity_);
    }

    function _fromidentity(Kernel.Identity identity_) internal pure returns (bytes10 identity) {
        identity = Kernel.Identity.unwrap(identity_);
    }


    function registerDependency(Kernel.Keycode keycode_) 
      external 
      onlyKernel  
    {
        hasDependency[keycode_] = true;
    }

    function setDependencies() 
      external 
      virtual 
      onlyKernel 
      returns (Kernel.Keycode[] memory dependencies) 
    {}

    function permissions()
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
    mapping(Policy => bool) approvedPolicies;
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
        admin = msg.sender;
        executor = msg.sender;
    }

    // ######################## ~ MODIFIERS ~ ########################

    modifier onlyAdmin() {
        if (msg.sender != admin) revert Kernel_OnlyAdmin(msg.sender);
        _;
    }

    modifier onlyExecutor() {
        if(msg.sender != executor) revert Kernel_OnlyExecutor(msg.sender);
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
            if ((char < 0x61 || char > 0x7A) && char != 0x00) {
              revert Kernel_InvalidIdentity(identity_);  // a-z only
            }
            unchecked { i++; }
        }
    }

    function registerIdentity(address address_, Identity identity_)
      public
      onlyAdmin
    {
      if (Identity.unwrap(getIdentityOfAddress[address_]) != bytes10(0) ) revert Kernel_AddressAlreadyHasIdentity(address_);
      if (getAddressOfIdentity[identity_] != address(0)) revert Kernel_IdentityAlreadyExistsForAddress(identity_);
      ensureValidIdentity(identity_);

      getIdentityOfAddress[address_] = identity_;
      getAddressOfIdentity[identity_] = address_;
    }


    function revokeIdentity(address address_)
      public
      onlyAdmin
    {
      Identity identityOfAddress = getIdentityOfAddress[address_];
      if (getAddressOfIdentity[identityOfAddress] == address(0)) revert Kernel_IdentityDoesNotExistForAddress(address_);
      getAddressOfIdentity[identityOfAddress] = address(0);
      getIdentityOfAddress[address_] = Identity.wrap(bytes10(0));
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
            revert Kernel_ModuleAlreadyInstalled(newModule_);
        
        getModuleForKeycode[keycode] = newModule_;
        getKeycodeForModule[newModule_] = keycode;

        newModule_.INIT();
    }

    function _upgradeModule(Module newModule_) internal {
        Keycode keycode = newModule_.KEYCODE();
        Module oldModule = getModuleForKeycode[keycode];

        if (address(oldModule) == address(0)) { revert Kernel_ModuleDoesNotExistForKeycode(keycode); }
        if (address(newModule_) == address(oldModule)) {revert Kernel_ModuleAlreadyInstalled(newModule_);}

        getKeycodeForModule[oldModule] = Keycode.wrap(bytes5(0));
        getKeycodeForModule[newModule_] = keycode;
        getModuleForKeycode[keycode] = newModule_;

        newModule_.INIT();

        // go through each policy in the Kernel and update its dependencies if they include the module
        for (uint i; i < allPolicies.length; ) {
            Policy policy = allPolicies[i];
            if (policy.hasDependency(keycode)) {
                policy.setDependencies();
            }

            unchecked {i++;}
        }
    }

    function _approvePolicy(Policy policy_) internal {
        if (approvedPolicies[policy_]) revert Kernel_PolicyAlreadyApproved(policy_);

        policy_.setDependencies();
        RequestPermissions[] memory requests = policy_.permissions();
        
        for (uint256 i = 0; i < requests.length; ) {
            RequestPermissions memory request = requests[i];

            policyPermissions[policy_][request.keycode][request.funcSelector] = true;

            policy_.registerDependency(request.keycode);

            emit PermissionsUpated(policy_, request.keycode, request.funcSelector, true);

            unchecked { i++; }

        }
        approvedPolicies[policy_] = true;
        allPolicies.push(policy_);
    }

    function _terminatePolicy(Policy policy_) internal {        
        if (!approvedPolicies[policy_]) revert Kernel_PolicyNotApproved(policy_);
        RequestPermissions[] memory requests = Policy(policy_).permissions();

        for (uint256 i; i < requests.length; ) {
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
              break;
            }
        }

        approvedPolicies[policy_] = false;
    }
}