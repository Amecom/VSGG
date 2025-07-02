# IVSGG Interface Documentation

This document provides a comprehensive overview of the `IVSGG` Solidity interface, designed for developers interacting with the Vibrant Seeds of the Gods' Garden (VSGG) protocol. This interface defines the public and external functions, events, and data structures of the core VSGG contract, allowing for seamless integration and interaction.

## Standard ERC Interfaces

The `IVSGG` interface extends several standard ERC interfaces, ensuring broad compatibility and adherence to established Ethereum token standards.

### IERC721Receiver

Defines the `onERC721Received` function, crucial for contracts to safely receive ERC-721 tokens:

```solidity
function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
```

**Developer Note:** Any contract designed to receive VSGG tokens via `safeTransferFrom` must implement this interface and return its selector (`this.onERC721Received.selector`).

### IERC165

Standard for interface detection:

```solidity
function supportsInterface(bytes4 interfaceId) external view returns (bool);
```

**Developer Note:** Allows external contracts to query if `IVSGG` supports specific interfaces.

### IERC173

Standard for contract ownership:

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
function owner() view external returns(address);
function transferOwnership(address _newOwner) external;
```

**Developer Note:** Confirms the VSGG contract has an owner and supports ownership transfer.

### IERC721

Core ERC-721 Non-Fungible Token standard:

```solidity
event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
function balanceOf(address owner) external view returns (uint256 balance);
function ownerOf(uint256 tokenId) external view returns (address owner);
function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
function safeTransferFrom(address from, address to, uint256 tokenId) external;
function transferFrom(address from, address to, uint256 tokenId) external;
function approve(address to, uint256 tokenId) external;
function setApprovalForAll(address operator, bool approved) external;
function getApproved(uint256 tokenId) external view returns (address operator);
function isApprovedForAll(address owner, address operator) external view returns (bool);
```

**Developer Note:** Provides standard NFT functionalities.

### IERC721Metadata

Optional ERC-721 extension for metadata:

```solidity
function name() external view returns (string memory);
function symbol() external view returns (string memory);
function tokenURI(uint256 tokenId) external view returns (string memory);
```

**Developer Note:** Retrieves token name, symbol, and metadata URI.

## IVSGG Interface Specifics

### Events

```solidity
event BaseURIUpdated(string newURI);
event ContractURIUpdated(string newURI);
event RecombinerAddressUpdated(address newAddress);
event TokenUpdated(uint256 tokenId);
```

### Structs

```solidity
struct Seed {
  uint256 seedType;
  uint256 mutations;
  bytes32 hash;
  uint8[256] code;
  uint8 allowUnsignedMutation;
  uint256 created;
  uint256 updated;
}
```

### Write Functions (Public)

```solidity
function claimContractOwnership() external;
function claimTokenOwnership(uint256 tokenId) external;
```

### Write Functions (Recombiner)

```solidity
function mint(address to) external;
function mint(address to, uint256 vsTokenIdA, uint256 vsTokenIdB, uint8[256] calldata code) external;
function mutate(uint256 tokenId, uint256 mutatorTokenId, uint8[256] calldata code) external;
function rollbackOwnership() external;
```

### Write Functions (Token Owner)

```solidity
function setUnsignedMutation(uint256 tokenId, bool allow) external;
```

### Write Functions (Contract Owner)

```solidity
function generate(uint256 tokenId, uint8[256] calldata code) external;
function setBaseURI(string calldata newURI) external;
function setContractURI(string calldata newURI) external;
function setRecombinerContract(address newAddress) external;
```

### Read Functions (View)

```solidity
function codeToHash(uint8[256] memory code) external view returns(bytes32);
function contractURI() external view returns (string memory);
function hashExists(bytes32 hash) external view returns (bool);
function hashExists(uint8[256] memory code) external view returns(bool);
function recombinerContract() external view returns (address);
function seedData(uint256 tokenId) external view returns (Seed memory);
function tokenOwnershipLockedBlocks() external view returns (uint256);
function totalSupply() external view returns (uint256);
function vibrantBalanceOf(address owner) external view returns (uint256);
function vibrantSupply() external view returns (uint256);
```

## IVSGGSErrors Interface

### ERC721 Errors

```solidity
error ERC721InvalidApprover(address approver);
error ERC721InvalidOwner(address owner);
error ERC721InvalidReceiver(address receiver);
error ERC721InvalidSender(address sender);
error ERC721InsufficientApproval(address operator, uint256 tokenId);
error ERC721InvalidOperator(address operator);
error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);
error ERC721NonexistentToken(uint256 tokenId);
```

### Generic Errors

```solidity
error BadCall();
error CallerNotAuthorized(address account);
```

### VSGG Specific Errors

```solidity
error ContractAddressRequired(address account);
error DuplicatedCode();
error InvalidCode(uint256 index, uint256 minAllowed, uint8 value, uint256 maxAllowed);
error OtherEraRequired(uint256 rightEra);
error OtherSeedTypeRequired(uint256 tokenId);
error VibrantSeedNotYetGenerated(uint256 tokenId);
```

---

This documentation should provide developers with a clear and comprehensive understanding of how to interact with the VSGG core contract, its unique features, and its error handling mechanisms.
