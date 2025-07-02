# VSGGGovernanceProtocol - Complete Technical Documentation

## General Description

`VSGGGovernanceProtocol` is a Solidity smart contract designed to custody ERC-721 compatible NFTs, with extended functionalities specific to the VSGG (Vibrant Seeds of the Gods' Garden) collection tokens. This contract represents one of the possible implementations of a DAO governance protocol that the community can adopt. The VSGG protocol is inherently flexible and allows for different implementations of DAO contracts to emerge and compete for management.

### The contract provides:

* Secure custody of vibrant VSGG NFTs (tokenId from 1 to 256).
* A dynamic voting system based on the custody of vibrant tokens to elect a "recombiner contract".
* An Ether distribution mechanism among vibrant tokens, taking custody into account.
* A community recovery mechanism for tokens mistakenly sent to the contract.
* A mechanism to claim ownership of the main VSGG protocol through the collective power of deposited tokens.

## Contract Purpose

The contract has five main objectives:

1. **Custody vibrant VSGG NFTs:**

   * Stores the original owner when a token is deposited and allows only that owner to claim it back.

2. **Manage governance for the recombiner:**

   * Each custodied token can vote for a recombiner address; the relative majority determines the active address.

3. **Distribute Ether equally to vibrant tokens:**

   * Ether sent to the contract is divided into 256 equal shares, and each tokenId (1-256) has an associated balance.

4. **Provide a community recovery mechanism:**

   * If a token is sent to the contract without being registered (e.g., via transferFrom), any DAO member can initiate the procedure to return it to a designated address.

5. **Assume ownership of the VSGG protocol:**

   * If the community deposits enough "vibrant" tokens to surpass the current owner's holdings, the contract can become the new owner of the main protocol, assuming all its powers.

## Main Requirements and Constraints

### 1. Acceptance only of vibrant VSGG tokens

* Tokens must come only from the VSGG contract (immutable).
* They must have a tokenId between 1 and 256.
* Controls are performed in `onERC721Received`.

### 2. No privileged roles (no owner)

* All operations are permissionless, and there is no owner of the contract.
* The choice of the recombiner and token recovery are also determined in a distributed manner by the community.

### 3. Error resilience

* NFTs mistakenly sent to the contract can be recovered through a collective action of the DAO, without requiring a privileged role.

## Architecture and Adopted Solutions

### Custody

* NFTs are received via `safeTransferFrom`, which triggers `onERC721Received`.
* The contract saves `originalOwner` and `deposited=true` in the `_custody` mapping.

### NFT Reclaim

* Only the original owner can reclaim the token using `claim(...)`.
* If the token had cast a vote for a recombiner, the vote is canceled.

### Recombiner Vote

* Each custodied token can vote for a `recombinerAddress`.
* Votes are stored per token (`_tokenVote`) and per candidate (`_recombinerVotes`).
* If a candidate surpasses the relative majority, they become the active `recombinerAddress`.

### Ether Distribution

* Received Ether is divided equally among the 256 tokenIds.
* Any token holder (whether custodied or not) can request withdrawal via `withdraw(...)` or `withdrawMultiple(...)`.

### VSGG Ownership Claim

* The contract exposes a `claimVsggOwnership()` function that can be called by anyone.
* This function attempts to have the contract claim ownership of the VSGG contract, but only succeeds if the number of custodied vibrant tokens exceeds that of the current owner of the VSGG contract.

### Mistaken Token Recovery

* If a token is sent via `transferFrom` (without triggering `onERC721Received`), it is not registered but is still owned by the contract.
* Any user who is a DAO member (i.e., holds at least one other custodied token) can call `communityRecoverUntrackedToken(...)`.
* This function allows the "stuck" token to be transferred to any address, resolving the error in a decentralized manner.

## Complete Interface (Public API)

### NFT Custody

* `function onERC721Received(...) external override returns (bytes4)`
  Receives an NFT via `safeTransferFrom`. Only VSGG tokens with `tokenId <= 256` are accepted.

* `function claim(address collection, uint256 tokenId) external`
  Allows the original owner to recover a deposited NFT. Also cancels any associated vote.

* `function isDeposited(address collection, uint256 tokenId) external view returns (bool)`
  Checks if a token is in custody.

* `function getOriginalOwner(address collection, uint256 tokenId) external view returns (address)`
  Returns the original owner saved at the time of deposit.

### Recombiner Vote

* `function voteRecombiner(uint256 tokenId, address candidate) external`
  Assigns a vote to the recombiner for a custodied token.

* `function checkAndUpdateRecombiner(address candidate) external`
  Manually updates the `recombinerAddress` if the candidate has surpassed the current one in votes.

* `function getRecombinerVotes(address candidate) external view returns (uint256)`
  Returns the number of active votes for a recombiner address.

* `function getTokenVote(uint256 tokenId) external view returns (address)`
  Returns the recombiner voted for by the specified token.

* `function applyRecombinerTo(address vsgg) external`
  Calls `setRecombinerContract(recombinerAddress)` on a compatible VSGG contract.

### Ether Management

* `receive() external payable`
  Receives Ether and distributes it in 256 equal shares (plus any randomly assigned remainder).

* `function withdraw(uint256 tokenId) external`
  Allows the token holder (on-chain or custodied) to withdraw Ether.

* `function withdrawMultiple(uint256[] calldata tokenIds) external`
  Aggregated withdrawal for multiple held tokens.

### Protocol Management and Recovery

* `function claimVsggOwnership() external`
  Attempts to have the contract claim ownership of the VSGG contract. The call is permissionless but only succeeds if the contract holds the required majority of "vibrant" tokens.

* `function communityRecoverUntrackedToken(uint256 memberTokenId, address collection, uint256 stuckTokenId, address recipient) external`
  Returns tokens mistakenly sent to the contract. The caller must prove they are a DAO member by providing a `memberTokenId` they have in custody.

* `function renewTokenOwnership(uint256 tokenId) external`
  Allows the original owner of a deposited token to renew its ownership by calling `claimTokenOwnership` on the VSGG contract. This avoids the need to withdraw and redeposit the token to update the inactivity timer.

### Utility

* `function getTokenOwner(uint256 tokenId) public view returns (address)`
  Returns the address to which Ether should be sent or the token returned (custody or `ownerOf`).

## Security

* The contract is non-upgradeable and ownerless.
* Reentrancy protection on all Ether operations (`withdraw`, `withdrawMultiple`).
* All writes are strictly controlled and cannot be modified by external entities not authorized by the contract's logic.
* It is not possible to seize foreign tokens: they can always be recovered by the original owner (if deposited correctly) or by the community (if sent by mistake).
