//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstant} from "script/HelperConfig.s.sol";

contract RaffleTest is CodeConstant, Test  {
     Raffle public raffle;      
     HelperConfig public helperConfig;



    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionID;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

     function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployRaffle();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionID = config.subscriptionID;

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouPayEnough() public {
        //Arrange
        vm.prank(PLAYER);

        //Act / Asset
        vm.expectRevert(Raffle.Raffle__NotEnoughETH.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public{
        //Arrange
        vm.prank(PLAYER);
        //Act
        raffle.enterRaffle{value: entranceFee}();
        //Assert
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvents() public {
        //Arrange
        vm.prank(PLAYER);
        //Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        //Assert
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpKeep("");
        
        //Act / Assert
         vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
         vm.prank(PLAYER);
         raffle.enterRaffle{value: entranceFee}();
    }


    /*//////////////////////////////////////////////////
                       CHECK UPKEEP
    //////////////////////////////////////////////////*/
    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act
        (bool upKeepNeded,) = raffle.checkUpkeep("");

        //Assert
        assert(!upKeepNeded);
    }

    function testCheckUpKeepReturnsFalseIfRaffleIsntOpen() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpKeep("");

        //Act
        (bool upKeepNeded,) = raffle.checkUpkeep("");

        //Assert
        assert(!upKeepNeded);
    }

    //Challenge
    //testCheckUpKeepReturnsFalseIfEnoughTimeHasPassed
    function testCheckUpKeepReturnsFalseIfEnoughTimeHasPassed() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpKeep("");

        //Act
        (bool upKeepNeded, ) = raffle.checkUpkeep("");

        //Assert 
        assert(!upKeepNeded);
    }
    //testCheckUpkeepReturnsTrueWhenParametersAreMet
        function  testCheckUpkeepReturnsTrueWhenParametersAreMet() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Assert 
        (bool upKeepNeded,) = raffle.checkUpkeep("");

        //Act
        assert(upKeepNeded);
        }

    /*//////////////////////////////////////////////////
                       PERFORM UPKEEP
    //////////////////////////////////////////////////*/
    modifier skipFork{
        if(block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsTrue() public skipFork {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        //Act / Assert 
        raffle.performUpKeep("");
    }

    function testPerformUpKeepRevertsIfCheckUpKeepFails() public skipFork {
        //Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        //Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpKeepNotNeeded.selector, currentBalance, numPlayers, rState)
        );
        raffle.performUpKeep("");
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

        function testPerformUpKeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {

        //Act
        vm.recordLogs();
        raffle.performUpKeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        //Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1);
    }

    /*//////////////////////////////////////////////////
                     FULFILLRANDOMWORDS
    //////////////////////////////////////////////////*/

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpKeep(uint256 randomRequestId) 
    public raffleEntered{
       //Arrange / Act / Assert
       vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
       VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntered {
          //Arrange
          uint256 additionalEntrance = 3; //4 total
          uint256 startingIndex = 1;
          address expectedWinner = address(1);

          for (uint256 i = startingIndex; i<startingIndex + additionalEntrance; i++){
            address newPlayer = address(uint160(i)); //address(1...)
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
          }

          uint256 startingTimeStamp = raffle.getLastTimeStamp();
          uint256 winnerStartingBalance = expectedWinner.balance;

        //Act
        vm.recordLogs();
        raffle.performUpKeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
        
        //Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize  = entranceFee * (additionalEntrance + 1);
        
        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        }
}
