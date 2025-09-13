//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() public {
        
    }

    function deployRaffle() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        //local -> deploy mocks, get local config
        //sepolia => get sep. config
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if(config.subscriptionID == 0) {
           //create subscription
           CreateSubscription createSubscription = new CreateSubscription();
           (config.subscriptionID, config.vrfCoordinator) = 
           createSubscription.createSubscription(config.vrfCoordinator, config.account);

           //Fund it
           FundSubscription fundSubscription = new FundSubscription();
           fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionID, config.link, config.account);
        }

        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
           config.entranceFee,
           config.interval,
           config.vrfCoordinator,
           config.gasLane,
           config.subscriptionID,
           config.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionID, config.account); 

        return(raffle, helperConfig);
    }
}