// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
//import {console} from "forge-std/console.sol";

/**
 * @title Raffle
 * @author Teo Zolota
 * @notice This contract is created for makind a raffle system.
 * @dev Implements Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus{
    /*Errors */
    error Raffle__NotEnoughETH();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpKeepNotNeeded(uint256 balance, uint256 playersLength, 
    uint256 raffleState);

    /*Type Declarations*/
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /*State Variables*/
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    // @dev The duration of the raffle in seconds
    uint256 private immutable i_interval;
    bytes32  private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    uint256 private immutable i_subscriptionId;
    uint256 private s_lastTimeStamp;
    address payable[] private s_players;
    address private s_recentWinner;
    RaffleState private s_raffleState;
    

    /*Events*/
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestRaffleWinner(uint256 indexed requestId);

    constructor(uint entranceFee, uint interval, address vrfCoordinator, bytes32 
    gaslane, uint256 subscriptionId, uint32 callbackGasLimit) 
    VRFConsumerBaseV2Plus (vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gaslane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }


    function enterRaffle() external payable {
        //require(msg.value >= i_entranceFee, "Not enough ETH sent!");
        //require(msg.value >= i_entranceFee, NotEnoughETH());
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughETH();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }


    /**
     * @dev This is the function that the Chainlink nodes will call to see if
     * the lottery is ready for a winner to be picked.
     * The following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is in an "open" state.
     * 3. The contract has ETH.
     * 4. Implicity, your subscription is funded with LINK.
     * @param -ignored
     * @return upkeepNeeded -true if it is time to restart the lottery.
     * @return -ignored
     */
    function checkUpkeep(bytes memory /* performData */) public view returns (
        bool upkeepNeeded,
        bytes memory /* performData */
        ) 
        {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = (s_players.length > 0);
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        
    }

    function performUpKeep(bytes calldata) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpKeepNotNeeded(address(this).balance, s_players.length,
            uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;

            uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId, 
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({
                        nativePayment: false
                    })
                )
            })
        );
        emit RequestRaffleWinner(requestId);
    }

    //CEI: Checks, Effects, Interactions
    function fulfillRandomWords(uint256, /*requestId*/ uint256[] calldata randomWords) 
    internal override {
       //Checks
       //conditionals

       //Effects(internal contract state)
       uint256 indexOfWinner = randomWords[0] % s_players.length;
       address payable recentWinner = s_players[indexOfWinner];
       s_recentWinner = recentWinner;

       s_raffleState = RaffleState.OPEN;
       s_players = new address payable[](0);
       s_lastTimeStamp = block.timestamp;
       
       //Interactions(external contract interactions)
       (bool success, ) = recentWinner.call{value: address(this).balance}("");
       if (!success) {
        revert Raffle__TransferFailed();
       }
       emit WinnerPicked(s_recentWinner);
}
    /*Getter functions*/
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address){
        return s_players[indexOfPlayer];
    } 
    
    function getLastTimeStamp() external view returns(uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns(address) {
        return s_recentWinner;
    }

}
