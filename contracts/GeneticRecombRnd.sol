// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IVSGG} from "https://github.com/Amecom/VSGG/blob/main/contracts/interfaces/IVSGG.sol";

/*
 * @title Genetic Recombination Contract
 * @author Amedeo C.
 * @notice This contract is for educational purposes and demonstrates genetic recombination in smart contracts.
 * @dev This contract allows the creation and mutation of Viable Seeds.
 * 
 * Contact Information:
 * - Author: Amedeo C.
 * - Email: amecom@gmail.com
 * - Website: https://www.vibrantseedsgodsgarden.com/
 *
 *
 * THIS CONTRACT SHOWS AN EXAMPLE OF VSGG GENETIC RECOMBINATION 
 * WITH RANDOMLY SELECTED VALUES WITHIN THE PERMITTED RANGES.
 *
 * Genetic recombination is used to create or mutate Viable Seeds,
 * while Vibrant Seeds cannot be generated or mutated. 
 * 
 * The main VSGG contract sets a few basic rules:
 *
 * Generating a Viable Seed:
 *
 * - The generation of Viable Seeds is only allowed after all Vibrant Seeds have been minted.
 *
 * - A Viable Seed can only be created through the genetic recombination of two consolidated Vibrant Seeds.
 *
 * - Valid genetic sequences must fall within the minimum and maximum values expressed by the
 *   parent Seeds at each corresponding position.
 *
 * Mutating a Viable Seed: 
 *
 * - Only the owner can alter the genetic code of a Viable Seed.
 *
 * - Mutation can occur by combining with any type of Seed, and valid sequences must adhere 
 *   to the minimum and maximum values set by both the original Viable Seed and the Seed 
 *   selected for recombination.
 *
 * Additionally:
 * 
 * - The newly generated or mutated genetic code must be unique, meaning it cannot 
 *   already exist in another Seed. 
 *
 * - Creating and mutating Viable Seeds requires a fee, which is paid to the owners of the Seeds involved.
 *   The fee amount is set by the Seed owners themselves.
 *
 * The selection of values for the new genetic sequence is handled by an external contract, which,
 * once authorized, can apply its own recombination rules. As this contract is replaceable, 
 * the logic for recombination can change over time.
 */


contract GeneticRecombRnd {

    // Define the VSGG contract address
    IVSGG private constant VSGG_CONTRACT = IVSGG(0x0000000000000000000000000000000000000000); 

    constructor() {}

    /**
     * @dev Mints a new Viable Seed using the genetic material from two Vibrant Seeds.
     * @param vsTokenIdA The tokenId of the consolidated Vibrant Seed (parent A).
     * @param vsTokenIdB The tokenId of the consolidated Vibrant Seed (parent B).
     */
    function mintViable(uint256 vsTokenIdA, uint256 vsTokenIdB) public payable {
        // Retrieve the DNA sequences of the parent Seeds.
        (uint8[300] memory dnaA, uint8[300] memory dnaB) = (
            VSGG_CONTRACT.tokenSeed(vsTokenIdA).dna, 
            VSGG_CONTRACT.tokenSeed(vsTokenIdB).dna
        );
        // Generate a new DNA sequence using a random recombination method.
        uint8[300] memory newDna = _generateRandomDna(dnaA, dnaB);
        // Call the mintViable function in the VSGG contract to mint the new Viable Seed.
        VSGG_CONTRACT.mintViable{value: msg.value}(msg.sender, vsTokenIdA, vsTokenIdB, newDna);
    }

    /**
     * @dev Mutates a Viable Seed's DNA by combining it with another Seed's DNA.
     * @param tokenId The tokenId of the Viable Seed to be mutated.
     * @param mutatorTokenId The tokenId of the Seed used for mutation.
     */
    function mutateViable(uint256 tokenId, uint256 mutatorTokenId) public payable {
        // Ensure the caller is the owner of the Viable Seed to be mutated.
        // NOTE: This check is also done in the VSGG contract using tx.origin.
        require(VSGG_CONTRACT.ownerOf(tokenId) == msg.sender, "NotOwned");

        // Retrieve the DNA sequences of the original and mutator Seeds.
        (uint8[300] memory originalDna, uint8[300] memory mutatorDna) = (
            VSGG_CONTRACT.tokenSeed(tokenId).dna, 
            VSGG_CONTRACT.tokenSeed(mutatorTokenId).dna
        );

        // Generate a new DNA sequence using a random recombination method.
        uint8[300] memory newDna = _generateRandomDna(originalDna, mutatorDna);

        // Call the mutateViable function in the VSGG contract to mutate the Seed's DNA.
        VSGG_CONTRACT.mutateViable{value: msg.value}(tokenId, mutatorTokenId, newDna);
    }

    /*
     * @dev Internal function to generate a random DNA sequence based on two parent DNAs.
     * @param dnaA The first DNA sequence.
     * @param dnaB The second DNA sequence.
     * return newDna A new DNA sequence generated from the parent DNAs.
     */
    function _generateRandomDna(uint8[300] memory dnaA, uint8[300] memory dnaB) 
        public 
        view  
        returns (uint8[300] memory) 
    {
        bytes32 seed = keccak256(abi.encodePacked(block.number, msg.sender));
        uint8[300] memory newDna;
        // Iterate through each position in the DNA sequences.
        for (uint256 i = 0; i < 300;) {
            // Generate a random number based on block information, sender address, and current index.
            uint256 randomInt = uint256(keccak256(abi.encodePacked(seed, i)));

            // Determine the minimum and maximum values between the two parent DNAs at the same position.
            uint256 minValue = dnaA[i] < dnaB[i] ? dnaA[i] : dnaB[i];
            uint256 maxValue = dnaA[i] > dnaB[i] ? dnaA[i] : dnaB[i];

            // Assign a random value within the determined range to the new DNA sequence.
            newDna[i] = uint8((randomInt % (maxValue - minValue + 1)) + minValue);

            // newDna[i] = uint8(v);
            unchecked {
                ++ i;
            }
        }
        return newDna;
    }

}