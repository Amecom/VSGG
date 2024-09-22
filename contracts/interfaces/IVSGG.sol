// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/*
 * @title VSGG Interface
 * @author Amedeo Celletti
 * 
 * Contact Information:
 * - Author: Amedeo Celletti
 * - Email: amecom@gmail.com
 * - Website: https://www.vibrantseedsgodsgarden.com/
 *
 */


// See https://eips.ethereum.org/EIPS/eip-721 
interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

// See https://eips.ethereum.org/EIPS/eip-165
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// See https://eips.ethereum.org/EIPS/eip-173
interface IERC173 /* is ERC165 */ {
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    function owner() view external returns(address);
    function transferOwnership(address _newOwner) external;	
}

// See https://eips.ethereum.org/EIPS/eip-721
interface IERC721 /* is IERC165 */ {
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
}

// See https://eips.ethereum.org/EIPS/eip-721 optional metadata extension 
interface IERC721Metadata /* is IERC721 */ {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// VSGG interface
interface IVSGG2 is IERC165, IERC173, IERC721, IERC721Metadata {

    /**
    * @dev Emitted when the base URI for token metadata is updated.
    * @param newURI The new base URI.
    */
    event BaseURIUpdated(string newURI);

    /**
    * @dev Emitted when the contract-level metadata URI is updated.
    * @param newURI The new contract URI.
    */
    event ContractURIUpdated(string newURI);

    /**
    * @dev Emitted when the Recombiner contract address is updated.
    * @param newAddress The new address of the Recombiner contract.
    */
    event RecombinerAddressUpdated(address newAddress);

    /**
    * @dev Emitted when a token's properties are updated.
    * @param tokenId The ID of the updated token.
    */
    event TokenUpdated(uint256 tokenId);

    struct Seed {
        uint256 seedType;  // 0 = Vibrant Not consolidated;  1 = Vibrant; 2 = Viable
        uint256 mutations;
        bytes32 hash;
        uint8[256] code;
        uint8 allowUnsignedMutation;        
        uint256 created;
        uint256 updated;
    }

    // WRITE (PUBLIC)

    /*
     * @notice Allows an account to take ownership of the contract. 
     * @dev Anyone who owns more Vibrant Seeds than the previous owner can take ownership of the contract. Once ownership is obtained, the new owner should call transferOwnership() to disable rollbackOwnership() and prove that they can manage the contract.
     * @dev The balance of the contract is sent to the previous owner.
     * Emits OwnershipTransferred event.
     * Raises OwnershipClosed if the ownership is still not open.
     * Raises CallerNotAuthorized if the applicant has fewer Vibrant Seeds than the current owner.
     */
    function claimContractOwnership() external;

    /**
     * @dev Updates the block number at which the.
     * This function is intended to be called when the unlock block number needs to be recalculated because the current owner is still active.
     */

    function claimTokenOwnership(uint256 tokenId) external;


    // WRITE (RECOMBINER)

    /*
     * @notice Mints a new Vibrant Seed must be managed by the `recombinerContract`.
     * @param to: The owner of the minted seed.
     * Emits Transfer event.
     */
    function mint(address to) external;

    /*
     * @notice Mints a new Viable Seed. 
     * @dev The recombination rules must be managed by the `recombinerContract`.
     * @param to: The owner of the minted seed.
     * @param vsTokenIdA: The tokenId of a consolidated Vibrant seed. 
     * @param vsTokenIdB: The tokenId of a consolidated Vibrant seed. 
     * @param code: Sequence of the new Viable Seed. 
     * Emits Transfer event.
     */
    function mint(address to, uint256 vsTokenIdA, uint256 vsTokenIdB, uint8[256] calldata code) external;

    /*
     * @notice Mutates the code of a Viable Seed.
     * @dev The recombination rules must be managed by the `recombinerContract`. The `recombinerContract` can mutate a Viable Seed without the owner's permission if the token's `AllowUnsignedMutation` is set to `1` (true). In this case, the `tx.origin` check is bypassed.
     * @param tokenId: The tokenId of the token to mutate.
     * @param mutatorTokenId: The tokenId with which the mutation occurs.
     * @param code: The new code of the token.
     * Emits TokenUpdated event.
     * Raises CallerNotAuthorized if the call is not from the recombinerContract.
     * Raises ERC721IncorrectOwner if the tokenId does not match tx.origin and seed[tokenId].allowUnsignedMutation is 0.
     * Raises OtherEraRequired if viable minting has not started.
     * Raises OtherSeedTypeRequired if tokenId is not a Viable seed.
     * Raises InvalidCode if the values in the sequence are not between the minimum and maximum values expressed by the tokenId and mutatorTokenId at the same position.
     * Raises DuplicatedCode if the seed code already exists.
     */
    function mutate(uint256 tokenId, uint256 mutatorTokenId, uint8[256] calldata code) external;

    /*
     * @notice Returns ownership of the contract to the previous owner.
     * @dev The balance of the contract is sent to the previous owner.
     * Emits OwnershipTransferred event.
     */
    function rollbackOwnership() external;

    // WRITE (TOKEN OWNER)

    /*
     * @notice Updates the `allowUnsignedMutation` setting for the token with the given `tokenId`.
     * @dev The variable controls whether a specific Viable Seed can be mutated without the explicit signature or approval of the token’s owner. The default value is false.
     * @param tokenId The ID of the token whose setting will be updated.
     * @param value Set to `true` to allow unsigned mutations; `false` otherwise.
     * Emits TokenUpdated event.
     * Raises `ERC721IncorrectOwner` if the caller is not the owner.
     */
    function setUnsignedMutation(uint256 tokenId, bool allow) external;


    // WRITE (CONTRACT OWNER)

    /*
     * @notice Consolidates information about a Vibrant Seed on the chain.
     * @dev Owner-only method. The consolidation can be overridden as long as ownership has not been opened.
     * @param tokenId: The tokenId to consolidate.
     * @param code: Seed code.
     * Raises CallerNotAuthorized if the caller is not the contract owner.
     * Raises OtherSeedTypeRequired if tokenId is not a Vibrant seed.
     * Raises DuplicatedCode if the code already exists.
     */
    function generate(uint256 tokenId, uint8[256] calldata code) external;

    /*
     * @notice Changes the base URL for a token's metadata.
     * @dev Owner-only method.
     * @param newURI: The new URL.
     * Emit BaseURIUpdated event
     * Raises CallerNotAuthorized if the caller is not the contract owner.
     */
    function setBaseURI(string calldata newURI) external; 

    /*
     * @notice Changes the URL for a contract's metadata.
     * @dev Owner-only method.
     * @param newURI: The new URL.
     * Emits ContractURIUpdated event.
     * Raises CallerNotAuthorized if the caller is not the contract owner.
     */
    function setContractURI(string calldata newURI) external; 

    /*
     * @notice Sets the address of the contract authorized to call the Viable Seed methods.
     * @dev Owner-only method. Non-reversible action.
     * @param newAddress: The address of the new contract.
     * Emits RecombinerUpdated event.
     * Raises CallerNotAuthorized if the caller is not the contract owner.
     * Raises ContractAddressRequired if newAddress is not Address(0) or a contract address.
     */
    function setRecombinerContract(address newAddress) external;


    // READ

    /*
     * @return the hash of a seed code.
     */
    function codeToHash(uint8[256] memory code) external pure returns(bytes32);

    /*
     * @return the URL with the contract metadata (as suggested by OpenSea).
     */
    function contractURI() external view returns (string memory);

    /*
     * @return true if the hash of a seed code has already been stored.
     */
    function hashExists(bytes32 hash) external view returns (bool);

    /*
     * @return true if the hash of a seed code has already been stored.
     */
    function hashExists(uint8[256] memory code) external returns(bool);

    /*
     * @return the address of the external contract that can call the mintViable and mutateViable functions.
     * @dev If this value is equal to address(0), it is possible to interact with these methods directly.
     */
    function recombinerContract() external view returns (address);

    /*
     * @return the IVSGGStruct-Seed structure of a `tokenId` seed.
     */
    function seedData(uint256 tokenId) external view returns (Seed memory);

    /*
     * @return The number of blocks that, when added to seed.updated, release the ownership of a token.
     */
    function tokenOwnershipLockedBlocks() external view returns (uint256);

    /**
     * @return the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /*
     * @return the number of Vibrant Seeds owned by the `owner` account. (Does not include Viable seeds)
     */
    function vibrantBalanceOf(address owner) external view returns (uint256);

    /*
     * @return the maximum supply of Vibrant Seeds. 
     */
    function vibrantSupply() external pure returns (uint256);

}


// VSGG Errors
interface IVSGGSErrors {

    // ERC721 Errors

    /**
     * @dev Indicates a failure related to the approval of a token. 
     * The address attempting the approval is not authorized to do so.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure due to an invalid owner address. 
     * For example, `address(0)` is a forbidden owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a failure with the `receiver` address when transferring tokens. 
     * The receiver address is not valid.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the token `sender` address. 
     * The sender address is not valid.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure due to insufficient approval by an operator. 
     * The operator is not approved to manage the token.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure due to an invalid operator address. 
     * The operator address is not valid.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);

    /**
     * @dev Indicates a failure related to the ownership of a particular token. 
     * The sender is not the owner of the token.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates that a token with a given ID does not exist. 
     * The owner of the token is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);


    // Generic Errors

    /**
     * @dev Indicate a bad call
     */
    error BadCall();

    /**
     * @dev Indicates that the caller is not authorized to perform an operation.
     * @param account Address of the unauthorized caller.
     */
    error CallerNotAuthorized(address account);


    //  Errors

    /**
     * @dev Indicates a failure to perform an action because the provided address is invalid. 
     * The address must be either a contract or the zero address.
     * @param account Address that is invalid.
     */
    error ContractAddressRequired(address account);

    /**
     * @dev Indicates that the code provided for a seed creation or mutation is already in use.
     */
    error DuplicatedCode();

    /**
    * @dev Indicates a failure to create or mutate a seed due to an invalid code sequence.
    * The code does not adhere to the basic recombination rules.
    * @param index The position of the first invalid element.
    * @param minAllowed The minimum allowed value (inclusive).
    * @param value The evaluated value.
    * @param maxAllowed The maximum allowed value (inclusive).
    */
    error InvalidCode(uint256 index, uint256 minAllowed, uint8 value, uint256 maxAllowed);


    /**
     * @dev Indicates a failure to perform an action because of current era.
     */
    error OtherEraRequired(uint256 rightEra);

    /**
     * @dev Indicates a failure to perform an action that requires a Vibrant Seed.
     * @param tokenId Identifier number of a token.
     */
    error OtherSeedTypeRequired(uint256 tokenId);

    /**
     * @dev Indicates a failure to mint a Vibrant Seed because the seed code is not consolidated yet.
     * @param tokenId Identifier number of a token.
     */
    error VibrantSeedNotYetGenerated(uint256 tokenId);

}

