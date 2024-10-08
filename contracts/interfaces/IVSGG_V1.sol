// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/*
 * @title VSGG Interface
 * @author Amedeo C.
 * 
 * Contact Information:
 * - Author: Amedeo C.
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
interface IVSGG is IERC165, IERC173, IERC721, IERC721Metadata {

    /**
    * @dev Emitted when the base URI for token metadata is updated.
    * @param newURI The new base URI.
    */
    event BaseUriUpdated(string newURI);

    /**
    * @dev Emitted when the contract fee is updated.
    * @param newFee The new fee amount.
    */
    event ContractFeeUpdated(uint256 newFee);

    /**
    * @dev Emitted when the contract-level metadata URI is updated.
    * @param newURI The new contract URI.
    */
    event ContractURIUpdated(string newURI);

    /**
    * @dev Emitted when the minting status is updated.
    * @param isMintingAllowed Indicates whether minting is allowed (true) or not (false).
    */
    event MintingStatusUpdated(bool isMintingAllowed);

    /**
    * @dev Emitted when ownership of the contract is opened, allowing claimOwnership method.
    */
    event OwnershipOpened();

    /**
    * @dev Emitted when the Recombiner contract address is updated.
    * @param newAddress The new address of the Recombiner contract.
    */
    event RecombinerUpdated(address newAddress);

    /**
    * @dev Emitted when a token's properties are updated.
    * @param tokenId The ID of the updated token.
    */
    event TokenUpdated(uint256 tokenId);

    struct Seed {
        uint256 seedType;  // 0 = Vibrant Not consolidated;  1 = Vibrant; 2 = Viable
        uint256 mutations;
        bytes32 hash;
        uint256 fee;
        uint8[300] code;
        uint8 allowUnsignedMutation;        
        uint8 fml;
        uint8 wht;
        uint8 ntr;
        uint8 blc;
        uint8 frc;
        uint8 cvr;
        uint8 isa;
        uint16 rpt;
        uint256 created;
        uint256 updated;
    }

    struct ContractSummary {
        string name;
        string symbol;
        address owner;
        uint256 vibrantMaxSupply;
        string contractURI;
        bool isMintAllowed;
        uint256 totalSupply;
        uint256 contractFee;
    }

    // WRITE (PUBLIC)

    /*
     * @notice Allows an account to take ownership of the contract. 
     * @dev Anyone who owns more Vibrant Seeds than the previous owner can take ownership of the contract. Once ownership is obtained, the new owner should call transferOwnership() to disable rollbackOwnership() and prove that they can manage the contract.
     * @dev The balance of the contract is sent to the previous owner.
     * Emits OwnershipTransferred event.
     * Raises VSGGOwnershipClosed if the ownership is still not open.
     * Raises CallerNotAuthorized if the applicant has fewer Vibrant Seeds than the current owner.
     */
    function claimOwnership() external;

    /*
     * @notice Mints a new Vibrant Seed.
     * @param to: The owner of the minted seed.
     * Emits Transfer event.
     * Raises VSGGMintingInactive if the minting phase is paused.
     * Raises VSGGVibrantSeedMintingClosed if the minting phase of the Vibrant Seeds is concluded.
     * Raises InsufficientValue if the value sent does not cover the fees required by the contract.
     */
    function mint(address to) external payable;

    /*
     * Calls the mint(address to) method, passing msg.sender as the value of 'to'.
     */
    function mint() external payable; 

    /*
     * @notice Mints a new Viable Seed. 
     * @dev The recombination rules must be managed by the `recombinerContract`.
     * @param to: The owner of the minted seed.
     * @param vsTokenIdA: The tokenId of a consolidated Vibrant seed. 
     * @param vsTokenIdB: The tokenId of a consolidated Vibrant seed. 
     * @param code: Sequence of the new Viable Seed. 
     * Emits Transfer event.
     * Raises CallerNotAuthorized if the call is not from the recombinerContract.
     * Raises InsufficientValue if the value sent does not cover the fees required by the vsTokenIdA, vsTokenIdB, and contract.
     * Raises VSGGViableSeedInactive if viable minting has not started.
     * Raises VSGGInvalidCode if the values in the sequence are not between the minimum and maximum values expressed by the parents at the same position.
     * Raises VSGGDuplicatedCode if the seed code already exists.
     */
    function mintViable(address to, uint256 vsTokenIdA, uint256 vsTokenIdB, uint8[300] calldata code) external payable;

    /*
     * @notice Returns ownership of the contract to the previous owner.
     * @dev The balance of the contract is sent to the previous owner.
     * Emits OwnershipTransferred event.
     * Raises VSGGOwnershipClosed.
     * Raises CallerNotAuthorized if the caller has fewer or the same number of Vibrant Seeds as the current owner.
     */
    function rollbackOwnership() external;

    // WRITE (TOKEN OWNER)

    /*
     * @notice Mutates the code of a Viable Seed.
     * @dev The recombination rules must be managed by the `recombinerContract`. The `recombinerContract` can mutate a Viable Seed without the owner's permission if the token's `AllowUnsignedMutation` is set to `1` (true). In this case, the `tx.origin` check is bypassed.
     * @param tokenId: The tokenId of the token to mutate.
     * @param mutatorTokenId: The tokenId with which the mutation occurs.
     * @param code: The new code of the token.
     * Emits TokenUpdated event.
     * Raises CallerNotAuthorized if the call is not from the recombinerContract.
     * Raises InsufficientValue if the value sent does not cover the fees required by mutatorTokenId and the contract.
     * Raises ERC721IncorrectOwner if the tokenId does not match tx.origin.
     * Raises VSGGViableSeedInactive if viable minting has not started.
     * Raises VSGGActionNotAllowedOnVibrantSeed if tokenId is not a Viable seed.
     * Raises VSGGInvalidCode if the values in the sequence are not between the minimum and maximum values expressed by the tokenId and mutatorTokenId at the same position.
     * Raises VSGGDuplicatedCode if the seed code already exists.
     */
    function mutateViable(uint256 tokenId, uint256 mutatorTokenId, uint8[300] calldata code) external payable;

    /*
     * @notice Updates the `allowUnsignedMutation` setting for the token with the given `tokenId`.
     * @dev The variable controls whether a specific Viable Seed can be mutated without the explicit signature or approval of the token’s owner. The default value is false.
     * @param tokenId The ID of the token whose setting will be updated.
     * @param value Set to `true` to allow unsigned mutations; `false` otherwise.
     * Emits TokenUpdated event.
     * Raises `ERC721IncorrectOwner` if the caller is not the owner.
     */
    function setTokenAllowUnsignedMutation(uint256 tokenId, bool value) external;

    /*
     * @notice Changes the fees required by the token owner for its use.
     * @dev The default value is 1000000000000000 (0,001 eth)
     * @param tokenId: The tokenId of the token to change the fees for.
     * @param amount: Fee value expressed in wei.
     * Emits TokenUpdated event.
     * Raises ERC721IncorrectOwner if the token owner is not the msg.sender.
     */
    function setTokenFee(uint256 tokenId, uint256 amount) external;

    // WRITE (CONTRACT OWNER)

    /*
     * @notice Opens up the ownership of the contract to anyone who wants to claim it.
     * @dev Owner-only method.
     * Emit OwnershipOpened event
     * Raises CallerNotAuthorized if the caller is not the contract owner.
     * Raises VSGGViableSeedInactive if the Viable Seed era has not started.
     */
    function openOwnership() external;

    /*
     * @notice Changes the base URL for a token's metadata.
     * @dev Owner-only method.
     * @param newURI: The new URL.
     * Emit BaseUriUpdated event
     * Raises CallerNotAuthorized if the caller is not the contract owner.
     */
    function setBaseURI(string calldata newURI) external; 

    /*
     * @notice Changes the fees required by the contract owner for Seed operations.
     * @dev Owner-only method.
     * @param amount: The new fee value in wei.
     * Emits ContractFeeUpdated event.
     * Raises CallerNotAuthorized if the caller is not the contract owner.
     */
    function setContractFee(uint256 amount) external;

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
     * Raises VSGGContractOrZeroAddressRequired if newAddress is not Address(0) or a contract address.
     */
    function setRecombinerContract(address newAddress) external;

    /*
     * @notice Consolidates information about a Vibrant Seed on the chain.
     * @dev Owner-only method. The consolidation can be overridden as long as ownership has not been opened.
     * @param tokenId: The tokenId to consolidate.
     * @param code: Seed code.
     * @param fml: Seed value.
     * @param wht: Seed value.
     * @param ntr: Seed value.
     * @param blc: Seed value.
     * @param frc: Seed value.
     * @param cvr: Seed value.
     * @param isa: Seed value.
     * @param rpt: Seed value.
     * Emits TokenUpdated event.
     * Raises CallerNotAuthorized if the caller is not the contract owner.
     * Raises VSGGVibrantSeedRequired if tokenId is not a Vibrant seed.
     * Raises VSGGTokenAlreadyConsolidated if the token is already consolidated and the ownership is open.
     * Raises VSGGDuplicatedCode if the code already exists.
     */
    function setTokenSeed(uint256 tokenId, uint8[300] calldata code, uint8 fml, uint8 wht, uint8 ntr, uint8 blc, uint8 frc, uint8 cvr, uint8 isa, uint16 rpt) external;

    /*
     * @notice Toggles the value of the minting status.
     * @dev Owner-only method.
     * Emits MintingStatusUpdated event. 
     * Raises CallerNotAuthorized if the caller is not the contract owner.
     */
    function toggleMintingStatus() external;

    /*
     * @notice Transfers ownership of the contract to another address.
     * @dev Owner-only method. The balance of the contract is sent to the previous owner.
     * @param newOwner: The address of the new owner.
     * Emits OwnershipTransferred event.
     * Raises CallerNotAuthorized if the caller is not the contract owner.
     */
    function transferOwnership(address newOwner) external; 

    // READ

    /*
     * @return the hash of a seed code.
     */
    function codeToHash(uint8[300] memory code) external pure returns(bytes32);

    /*
     * @return the fee the contract owner receives when a seed is created or mutated.
     */
    function contractFee() external view returns (uint256); 

    /*
     * @return aggregate information about the contract [IVSGGStruct-ContractSummary].
     */
    function contractSummary() external view returns (ContractSummary memory);

    /*
     * @return the URL with the contract metadata (as suggested by OpenSea).
     */
    function contractURI() external view returns (string memory);

    /*
     * @return true if the hash of a seed code has already been stored.
     */
    function hashExists(bytes32 hash) external view returns (bool);

    /*
     * @return true if seed minting or mutating is enabled.
     */
    function isMintingAllowed() external view returns (bool);

    /*
     * @return true if the ability to claim ownership of the contract is enabled.
     */
    function isOwnershipOpen() external view returns (bool);


    /*
     * @return the contract owner address.
     */
    function owner() external view returns (address);

    /*
     * @return the address of the external contract that can call the mintViable and mutateViable functions.
     * @dev If this value is equal to address(0), it is possible to interact with these methods directly.
     */
    function recombinerContract() external view returns (address);

    /*
     * @return the IVSGGStruct-Seed structure of a `tokenId` token.
     */
    function tokenSeed(uint256 tokenId) external view returns (Seed memory);

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
    function vibrantMaxSupply() external pure returns (uint256);

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

    /**
     * @dev Indicates that a call to an address target failed. 
     * The target may have reverted.
     */
    error ExternalCallFailed();

    /**
    * @dev Error indicating that the ETH value sent is insufficient to perform the operation.
    * @param requiredValue The minimum required value.
    * @param sentValue The value that was sent.
    */
    error InsufficientValue(uint256 requiredValue, uint256 sentValue);

    /**
     * @dev Indicates that a reentrant call was detected, which is not allowed.
     */
    error ReentrantCallDetected();


    // VSGG Errors

    /**
     * @dev Indicates that an action is not allowed on a Vibrant Seed. 
     * This error is used in the mutateViable function.
     */
    error VSGGActionNotAllowedOnVibrantSeed(uint256 tokenId);

    /**
     * @dev Indicates a failure to perform an action because the provided address is invalid. 
     * The address must be either a contract or the zero address.
     * @param account Address that is invalid.
     */
    error VSGGContractOrZeroAddressRequired(address account);

    /**
     * @dev Indicates that the code provided for a seed creation or mutation is already in use.
     */
    error VSGGDuplicatedCode();

    /**
    * @dev Indicates a failure to create or mutate a seed due to an invalid code sequence.
    * The code does not adhere to the basic recombination rules.
    * @param index The position of the first invalid element.
    * @param minAllowed The minimum allowed value (inclusive).
    * @param value The evaluated value.
    * @param maxAllowed The maximum allowed value (inclusive).
    */
    error VSGGInvalidCode(uint256 index, uint256 minAllowed, uint8 value, uint256 maxAllowed);

    /**
     * @dev Indicates that minting is not currently active, and the action cannot be performed.
     */
    error VSGGMintingInactive();

    /**
     * @dev Indicates a failure to perform an action because the contract ownership should be open but is not yet.
     */
    error VSGGOwnershipClosed();

    /**
     * @dev Indicates a failure to consolidate a Vibrant Seed because it is already consolidated. 
     * This error only occurs when the contract has been opened for ownership.
     * @param tokenId Identifier number of a token.
     */
    error VSGGTokenAlreadyConsolidated(uint256 tokenId);

    /**
     * @dev Indicates a failure to perform an action on a Viable Seed because the minting of Vibrant Seeds has not finished.
     */
    error VSGGViableSeedInactive();

    /**
     * @dev Indicates a failure to mint a Vibrant Seed because the minting of Vibrant Seeds has finished.
     */
    error VSGGVibrantSeedMintingClosed();

    /**
     * @dev Indicates a failure to perform an action that requires a Vibrant Seed.
     * @param tokenId Identifier number of a token.
     */
    error VSGGVibrantSeedRequired(uint256 tokenId);

}

