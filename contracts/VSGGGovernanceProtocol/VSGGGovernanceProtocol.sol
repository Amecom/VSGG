// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Interfaccia unificata per le funzioni core del contratto VSGG relative a ownership, claim dei token e gestione del recombiner
interface IVSGG_CoreFunctions {
    function claimContractOwnership() external;
    function owner() external view returns (address);
    function claimTokenOwnership(uint256 tokenId) external;
    function setRecombinerContract(address newAddress) external; // Funzione spostata qui
}


contract VSGGGovernanceProtocol is IERC721Receiver, ReentrancyGuard {
    struct CustodyInfo {
        address originalOwner;
        bool deposited;
    }

    uint256 public constant MAX_TOKENS = 256;
    address public immutable vsggContract;
    mapping(uint256 => uint256) public tokenBalance;
    mapping(address => mapping(uint256 => CustodyInfo)) private _custody;
    mapping(uint256 => address) private _tokenVote;
    mapping(address => uint256) private _recombinerVotes;

    address public recombinerAddress;

    event TokenDeposited(address indexed collection, uint256 indexed tokenId, address indexed owner);
    event TokenClaimed(address indexed collection, uint256 indexed tokenId, address indexed owner);
    event RecombinerAddressUpdated(address newAddress);
    event RecombinerApplied(address vsggContract, address recombinerAddress);
    event EtherReceived(address indexed sender, uint256 amount);
    event EtherWithdrawn(address indexed owner, uint256 amount);

    constructor(address _vsggContract) {
        vsggContract = _vsggContract;
    }

    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        require(msg.sender == vsggContract, "Only VSGG contract allowed");
        require(tokenId >= 1 && tokenId <= MAX_TOKENS, "Only tokenId <= 256 allowed");
        require(!_custody[msg.sender][tokenId].deposited, "Already deposited");
        _custody[msg.sender][tokenId] = CustodyInfo({ originalOwner: from, deposited: true });

        emit TokenDeposited(msg.sender, tokenId, from);
        return this.onERC721Received.selector;
    }

    function claimVsggOwnership() external {
        require(IVSGG_CoreFunctions(vsggContract).owner() != address(this), "Vault is already the owner");
        IVSGG_CoreFunctions(vsggContract).claimContractOwnership();
    }

    function communityRecoverUntrackedToken(
        uint256 memberTokenId,
        address collection,
        uint256 stuckTokenId,
        address recipient
    ) external {
        CustodyInfo memory memberInfo = _custody[vsggContract][memberTokenId];
        require(memberInfo.deposited, "Caller is not a DAO member");
        require(memberInfo.originalOwner == msg.sender, "Caller not owner of member token");

        require(!_custody[collection][stuckTokenId].deposited, "Token is already managed");

        require(IERC721(collection).ownerOf(stuckTokenId) == address(this), "Vault does not own the token");

        IERC721(collection).safeTransferFrom(address(this), recipient, stuckTokenId);
    }

    // Nuova funzione per rinnovare la proprietà di un token depositato
    /**
     * @notice Permette al proprietario originale di un token depositato di rinnovarne la proprietà
     * chiamando claimTokenOwnership sul contratto VSGG.
     * @dev Questo evita la necessità di prelevare e ridepositare il token per aggiornare il timer di inattività.
     * @param tokenId L'ID del token di cui si vuole rinnovare la proprietà.
     */
    function renewTokenOwnership(uint256 tokenId) external {
        // Verifica che il token sia effettivamente in custodia in questo contratto
        CustodyInfo memory info = _custody[vsggContract][tokenId];
        require(info.deposited, "Token not deposited in this protocol");

        // Verifica che il chiamante sia il proprietario originale del token in custodia
        require(info.originalOwner == msg.sender, "Not the original owner of the deposited token");

        // Chiama la funzione claimTokenOwnership sul contratto VSGG
        IVSGG_CoreFunctions(vsggContract).claimTokenOwnership(tokenId);
    }

    function claim(address collection, uint256 tokenId) external {
        CustodyInfo memory info = _custody[collection][tokenId];
        require(info.deposited, "Token not deposited");
        require(info.originalOwner == msg.sender, "Not original owner");

        address voted = _tokenVote[tokenId];
        if (voted != address(0)) {
            _recombinerVotes[voted] -= 1;
            delete _tokenVote[tokenId];
        }

        delete _custody[collection][tokenId];
        IERC721(collection).safeTransferFrom(address(this), msg.sender, tokenId);
        emit TokenClaimed(collection, tokenId, msg.sender);
    }

    function isDeposited(address collection, uint256 tokenId) external view returns (bool) {
        return _custody[collection][tokenId].deposited;
    }

    function getOriginalOwner(address collection, uint256 tokenId) external view returns (address) {
        return _custody[collection][tokenId].originalOwner;
    }

    function voteRecombiner(uint256 tokenId, address candidate) external {
        require(_custody[vsggContract][tokenId].deposited, "Token not in custody");
        require(_custody[vsggContract][tokenId].originalOwner == msg.sender, "Not original owner");

        address prev = _tokenVote[tokenId];
        if (prev == candidate) return;
        if (prev != address(0)) _recombinerVotes[prev] -= 1;

        _tokenVote[tokenId] = candidate;
        _recombinerVotes[candidate] += 1;
        if (_recombinerVotes[candidate] > _recombinerVotes[recombinerAddress]) {
            recombinerAddress = candidate;
            emit RecombinerAddressUpdated(candidate);
        }
    }

    function checkAndUpdateRecombiner(address candidate) external {
        require(_recombinerVotes[candidate] > _recombinerVotes[recombinerAddress], "Not majority");
        recombinerAddress = candidate;
        emit RecombinerAddressUpdated(candidate);
    }

    function getRecombinerVotes(address candidate) external view returns (uint256) {
        return _recombinerVotes[candidate];
    }

    function getTokenVote(uint256 tokenId) external view returns (address) {
        return _tokenVote[tokenId];
    }

    function applyRecombinerTo(address vsgg) external {
        IVSGG_CoreFunctions(vsgg).setRecombinerContract(recombinerAddress);
        emit RecombinerApplied(vsgg, recombinerAddress);
    }

    receive() external payable {
        require(msg.value > 0, "No Ether received");
        uint256 share = msg.value / MAX_TOKENS;
        uint256 remainder = msg.value % MAX_TOKENS;
        for (uint256 i = 1; i <= MAX_TOKENS; i++) {
            tokenBalance[i] += share;
        }

        tokenBalance[_randomToken()] += remainder;
        emit EtherReceived(msg.sender, msg.value);
    }

    function withdraw(uint256 tokenId) external nonReentrant {
        require(tokenId >= 1 && tokenId <= MAX_TOKENS, "Invalid token ID");
        address recipient = getTokenOwner(tokenId);
        require(msg.sender == recipient, "Not token owner");

        uint256 amount = tokenBalance[tokenId];
        require(amount > 0, "No balance");
        tokenBalance[tokenId] = 0;

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Withdraw failed");

        emit EtherWithdrawn(msg.sender, amount);
    }

    function withdrawMultiple(uint256[] calldata tokenIds) external nonReentrant {
        uint256 total = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(tokenId >= 1 && tokenId <= MAX_TOKENS, "Invalid token ID");

            address recipient = getTokenOwner(tokenId);
            require(msg.sender == recipient, "Not token owner");
            uint256 amount = tokenBalance[tokenId];
            if (amount > 0) {
                total += amount;
                tokenBalance[tokenId] = 0;
            }
        }

        require(total > 0, "No funds");
        (bool success, ) = msg.sender.call{value: total}("");
        require(success, "Withdraw failed");

        emit EtherWithdrawn(msg.sender, total);
    }

    function getTokenOwner(uint256 tokenId) public view returns (address) {
        if (_custody[vsggContract][tokenId].deposited) {
            return _custody[vsggContract][tokenId].originalOwner;
        } else {
            return IERC721(vsggContract).ownerOf(tokenId);
        }
    }

    function _randomToken() private view returns (uint256) {
        return (uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender))) % MAX_TOKENS) + 1;
    }
}
