# [The Default Framework: A New Standard for Protocol Development](https://palm-cause-2bd.notion.site/The-Default-Framework-A-New-Standard-for-Protocol-Development-7f8ace6d263c4303b108dc5f8c3055b1)

  

Today, most projects take a process-centric approach towards protocol development: each smart contract is developed to manage a process along a chain of logic that is triggered when external interactions occur.

  

This is generally the most intuitive approach because it’s how our brain thinks when designing systems: one step in logic at a time. However, there’s an inherent issue in building a protocol this way. Over time, as the protocol evolves, more “steps in logic” are added across the system, creating long and convoluted chains of processes that look like this:

  

![MakerDAO’s protocol architecture.](https://3475401041-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2F-LtJ1VeNJVW-jiKH0xoL%2Fuploads%2Fuu2gnwI8XK0MXMGImPgD%2FMCD%20System%202.1.png?alt=media&token=a7898b0e-71a3-460b-a6e9-6b95b40d66f6)
[MakerDAO's protocol architecture](https://docs.makerdao.com/)
  

or this:

  

![Aave’s protocol architecture.](https://2799188404-files.gitbook.io/~/files/v0/b/gitbook-legacy-files/o/assets%2F-M3C77KySce4HXyLqkEq%2F-MNbklkK7vNPshPbrCZ-%2F-MNbxHseq3eFT7u8gEo3%2Fimage.png?alt=media&token=61a006eb-8d2b-4de6-8498-05fc889feed3)
[Aave’s protocol architecture.](https://docs.aave.com/developers/v/2.0/the-core-protocol/protocol-overview)

  

When protocols are architected in these “web-like” structures, they can be difficult to understand, as they break a simple interaction into multiple layers of abstract logic. When contracts are developed this way, it’s difficult to track down where the calls are coming from or going to—it’s easy to get lost in the web of logic. This puts a huge burden on a user trying to understand the system, often requiring them to read an excessive amount of documentation just to figure out what’s going on behind the scenes.

  

This pattern can be frustrating to deal with, and discouraging developers from contributing to the existing codebase or integrating with the protocol. And when they do, it increases the potential for bugs and unintended behavior to occur.

  

---

  

The core philosophy of Default is to shift the focus of writing contracts away from organizing contracts around processes, and towards organizing contracts around data models. In particular, what data models exist as protocol dependencies, and how they can be modified.

  

The goal is to turn a protocol from looking something like this:

  

![](https://palm-cause-2bd.notion.site/image/https%3A%2F%2Fs3-us-west-2.amazonaws.com%2Fsecure.notion-static.com%2Fcd291f59-ff4b-46ab-862f-ba75035eb300%2FScreen_Shot_2022-04-25_at_1.47.18_PM.png?table=block&id=6955f9be-5ab2-45e5-bed3-ea04dd501b68&spaceId=230cab04-4299-47f6-b410-f03193a88f89&width=2000&userId=&cache=v2)

  

into something look like this:

  

![](https://palm-cause-2bd.notion.site/image/https%3A%2F%2Fs3-us-west-2.amazonaws.com%2Fsecure.notion-static.com%2Ff43c07ce-94e6-4bde-a76c-e6de6118bd3c%2FScreen_Shot_2022-04-25_at_12.21.11_PM.png?table=block&id=aff0cffb-851f-4fdd-9625-ddf0925d63e8&spaceId=230cab04-4299-47f6-b410-f03193a88f89&width=2000&userId=&cache=v2)

  

With a consistent contract architecture, developers can make certain assumptions around the intended behavior for any given contract in the protocol even if they are unfamiliar with the code. This model also limits the maximum depth of dependencies to a single contract, removing the potential for long or circular dependency chains to form.

  

The idea to separate data and business logic isn’t novel; it just hasn’t been applied to smart contract development yet. Default is inspired by existing design patterns in other areas of computing that are more mature, like computer operating systems and web development.

  

# The Default Framework
  

In Default, contracts are either Modules or Policies, which are essentially the “front-end” and “back-end” of a protocol: Modules are the back-end, and Policies are the front-end.

  

Modules are **internal-facing contracts** that store shared state across the protocol. You can think of them as microservices: each Module is responsible for managing a particular data model within the larger system. Modules can only be accessed through whitelisted Policy contracts, and have no dependencies of their own. Modules can only modify their own internal state.

  

Policies are **external-facing contracts** that receive inbound calls to the protocol, and routes all the necessary updates to data models via Modules. Policies effectively act as intermediaries between external interactions and internal state changes, creating a buffer where all protocol business logic is composed.

  

While modules describe *what* data models exist within the protocol and *how* they can be modified, policy contracts contain the context for *why* those changes happen. This separation of *what* and *why* in the protocol allows for greater flexibility in design while retaining some properties of immutability, which dramatically simplifies protocol development.

  

---

  

One example of a module could be an ERC20 token: ERC20 contracts define a self-contained data model around token account balances (i.e. `balanceOf`). The `transfer()`, `mint()`, and `burn()` functions define how account balances can be changed, while the `totalSupply()` function provides useful metadata about balances, such as the aggregate amount of balances in existence.

  

Notice that changes in an ERC20 contract are limited to its internal state: nothing happens outside the contract when account balances are modified. This makes ERC20’s generic enough to be applicable for a wide variety of use cases, like managing vault deposits, facilitating token swaps, or distributing mining rewards for a protocol.

  

There is an interesting case about this example: Module functions should not be called by any contracts except Policies. However, users should be able to interact directly with the ERC20 via transfer(). How is this case handled?

  

The ultimate disctinction lies in *permissioned* versus *permissionless* state changes. When a contract needs to enforce certain permissionless guarantees, those functions should be atomic in the contract and called directly by the user. Default is mostly applicable to permissioned functions, like `mint()` and `burn()`. Interesting cases like `transferFrom()` emerge—should external integrations be permissioned or permissionless? This is up to the protocol to decide.

  

## Protocol Organization and Upgradability

  

Default views the entire contract set as a cohesive unit: rather than upgrading an individual contract’s code, its better to just upgrade the protocol’s *contract set.* In Default, there is a special contract registry that manages the contract set called the Kernel. This means that all changes to the protocol are made within in a single contract, unifying the model of upgradability.

  

In this paradigm, each contract in the protocol remains immutable, but the set of contracts that make up a protocol can change. This makes Default incredibly easy to work with; developers only need to understand a single contract—the Kernel—before they can begin building a protocol using the framework.

  

### Kernel.sol

  

There are a limited number of actions that the Kernel can take to update the protocol. These actions are:

  

**1. Approving a policy**

  

**2. Terminating a policy**

  

**3. Installing a module**

  

**4. Upgrading a module**

  

Each of these actions is executed on a “target”, which is the address of the contract on which the action is being performed. This combination of an action and a target is submitted as an “instruction” in the Kernel: approve 0xc199e... as a Policy, install 0x410f... as a Module, etc.

  

Policies are a*pproved* or *terminated* via simple whitelist in the Kernel. The whitelist is represented as a mapping of contract addresses to a boolean that represents whether that policy is authorized to interact with modules. Once a policy is terminated, it is no longer authorized to call modules, effectively deprecating the feature.

  

Modules can be *installed* or *upgraded* with a directory in the Kernel. Each module is mapping their address to a three letter keycode in the Kernel, which is used to reference the underlying data model of the module from within Policies. For example, a token module might have the keycode “TKN”, while a treasury module might have the keycode “TSY”. Once installed, a module cannot be removed, only upgraded.

  

This to ensure some backwards compatibility for contract dependencies in Policy contracts: once a keycode is mapped to a module in the Kernel, it will always point to an existing data model. Keycodes are three letters to discourage module bloat as well as reduce potential confusion around dependency names.

  

---

  

### The Executor

  

In the Kernel.sol contract code, there’s one action that hasn’t been discussed: changing the executor. In the Kernel, the executor is the address with the permission to execute instructions—you can think of the executor as the “owner” of the Kernel contract.

  

The initial “executor” is the deployer of a Kernel contract, but can be changed to another address to include possibilities for on-chain governance via `changeExecutor()`. For convenience, Default has an optional module that can be installed in any Kernel called “GPU”, which enables a protocol to execute multiple instructions in the same transaction, simplifying multi-contract migrations.

  

---

  

By defining all the protocol changes in a single contract, Default is a very lightweight and simple framework to adopt. Developers only need to understand how the Kernel works before building any type of protocol on top: whether they are DeFi protocols, NFT marketplaces, or DAO tooling.