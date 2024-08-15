// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVSGG} from "https://github.com/Amecom/VSGG/blob/main/contracts/interfaces/IVSGG.sol";

/*
 * @title Recombination Contract
 * @author Amedeo C.
 * @notice This contract is for educational purposes and demonstrates seed recombination in smart contracts.
 * @dev This contract allows the creation and mutation of Viable Seeds.
 * 
 * Contact Information:
 * - Author: Amedeo C.
 * - Email: amecom@gmail.com
 * - Website: https://www.vibrantseedsgodsgarden.com/
 *
 *
 * THIS CONTRACT SHOWS AN EXAMPLE OF SEED RECOMBINATION 
 * WITH RANDOMLY SELECTED VALUES WITHIN THE PERMITTED RANGES.
 *
 * Recombination is used to create or mutate Viable Seeds,
 * while Vibrant Seeds cannot be generated or mutated. 
 * 
 * The main VSGG contract sets a few basic rules:
 *
 * Generating a Viable Seed:
 *
 * - The generation of Viable Seeds is only allowed after all Vibrant Seeds have been minted.
 *
 * - A Viable Seed can only be created through the recombination of two consolidated Vibrant Seeds.
 *
 * - Valid sequences must fall within the minimum and maximum values expressed by the
 *   parent Seeds at each corresponding position.
 *
 * Mutating a Viable Seed: 
 *
 * - Only the owner can alter the sequence of a Viable Seed.
 *
 * - Mutation can occur by combining with any type of Seed, and valid sequences must adhere 
 *   to the minimum and maximum values set by both the original Viable Seed and the Seed 
 *   selected for recombination.
 *
 * Additionally:
 * 
 * - The newly generated or mutated sequence must be unique, meaning it cannot 
 *   already exist in another Seed. 
 *
 * - Creating and mutating Viable Seeds requires a fee, which is paid to the owners of the Seeds involved.
 *   The fee amount is set by the Seed owners themselves.
 *
 * The selection of values for the new sequence is handled by an external contract, which,
 * once authorized, can apply its own recombination rules. As this contract is replaceable, 
 * the logic for recombination can change over time.
 */


contract RecombinerRnd {

    // Define the VSGG contract address (Sepolia:0x59E8C72430cCEF9d09a8B3a378D5c541574630d2)
    IVSGG private constant VSGG_CONTRACT = IVSGG(0x1426AA39949DB3dC328F4d28e5a599e7E5790ddc); 

    constructor() {}

    /**
     * @dev Mints a new Viable Seed using the sequences from two consolidated Vibrant Seeds.
     * @param vsTokenIdA The tokenId of the consolidated Vibrant Seed (parent A).
     * @param vsTokenIdB The tokenId of the consolidated Vibrant Seed (parent B).
     */
    function mintViable(uint256 vsTokenIdA, uint256 vsTokenIdB) public payable {
        // Retrieve the code of the parent Seeds.
        (uint8[300] memory codeA, uint8[300] memory codeB) = (
            VSGG_CONTRACT.tokenSeed(vsTokenIdA).code, 
            VSGG_CONTRACT.tokenSeed(vsTokenIdB).code
        );
        // Generate a new code  using a random recombination method.
        uint8[300] memory newCode = _generateRandomCode(codeA, codeB);
        // Call the mintViable function in the VSGG contract to mint the new Viable Seed.
        VSGG_CONTRACT.mintViable{value: msg.value}(msg.sender, vsTokenIdA, vsTokenIdB, newCode);
    }

    /**
     * @dev Mutates a Viable Seed's code by combining it with another Seed's code.
     * @param tokenId The tokenId of the Viable Seed to be mutated.
     * @param mutatorTokenId The tokenId of the Seed used for mutation.
     */
    function mutateViable(uint256 tokenId, uint256 mutatorTokenId) public payable {
        // Ensure the caller is the owner of the Viable Seed to be mutated.
        // NOTE: This check is also done in the VSGG contract using tx.origin.
        require(VSGG_CONTRACT.ownerOf(tokenId) == msg.sender, "NotOwned");
        _mutate(tokenId, mutatorTokenId);
    }

    /**
     * @dev Unlike mutateViable, this method does not verify token ownership before mutation. 
     * This is only possible for Viable Seeds with allowUnsignedMutation set to 1 (true).
     * By default, this is 0 (false). 
     * When allowUnsignedMutation is enabled, the VSGG contract bypasses the tx.origin check during mutateViable calls. 
     * In a real-world context, mutateViableUnsigned should still be called only by the owner of the Recombiner contract.
     * @param tokenId The tokenId of the Viable Seed to be mutated.
     * @param mutatorTokenId The tokenId of the Seed used for mutation.
     */
    function mutateViableUnsigned(uint256 tokenId, uint256 mutatorTokenId) public payable {
        _mutate(tokenId, mutatorTokenId);
    }

    function _mutate(uint256 tokenId, uint256 mutatorTokenId) internal {
        // Retrieve the code of the original and mutator Seeds.
        (uint8[300] memory originalCode, uint8[300] memory mutatorCode) = (
            VSGG_CONTRACT.tokenSeed(tokenId).code, 
            VSGG_CONTRACT.tokenSeed(mutatorTokenId).code
        );
        // Generate a new code using a random recombination method.
        uint8[300] memory newCode = _generateRandomCode(originalCode, mutatorCode);
        // Call the mutateViable function in the VSGG contract to mutate the Seed's code.
        VSGG_CONTRACT.mutateViable{value: msg.value}(tokenId, mutatorTokenId, newCode);
    }


    /*
     * @dev Internal function to generate a random code based on two parent codes.
     * @param codeA The first seed code.
     * @param codeB The second seed code.
     * return newCode A new code generated from the parent codes.
     */
    function _generateRandomCode(uint8[300] memory codeA, uint8[300] memory codeB) 
        internal 
        view  
        returns (uint8[300] memory) 
    {
        bytes32 seed = keccak256(abi.encodePacked(block.number, msg.sender));
        uint8[300] memory newCode;
        uint16 minValue;
        uint16 maxValue;
        uint256 randomInt;
        // Iterate through each position in the code sequences.
        for (uint256 i = 0; i < 300;) {
            // Generate a random number based on block information, sender address, and current index.
            randomInt = uint256(keccak256(abi.encodePacked(seed, i)));
            // Determine the minimum and maximum values between the two parent codes at the same position.
            minValue = codeA[i] < codeB[i] ? codeA[i] : codeB[i];
            maxValue = codeA[i] > codeB[i] ? codeA[i] : codeB[i];
            // Assign a random value within the determined range to the new code sequence.
            unchecked {
                newCode[i] = uint8((randomInt % (maxValue - minValue + 1)) + minValue);
                ++ i;
            }
        }
        return newCode;
    }

}