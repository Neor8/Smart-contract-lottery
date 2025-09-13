//SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

abstract contract CodeConstant {
    /* VRF coordinator values */
    uint96 public  baseFee =  0.25 ether;
    uint96 public gasprice = 1e9;
    //LINK / ETH price
    int256 mockWeiPerUint = 4e15;

    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstant, Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint256 subscriptionID;
        address link;
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainID => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaETH();
    }

    function getConfigByChainID(uint256 chainID) public returns(NetworkConfig memory) {
        if (networkConfigs[chainID].vrfCoordinator != address(0)){
            return(networkConfigs[chainID]);
        } else if (chainID == LOCAL_CHAIN_ID){
           return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    } 

    function getConfig() public returns(NetworkConfig memory){
        return getConfigByChainID(block.chainid);
    }

    function getSepoliaETH() public pure returns(NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,
            subscriptionID: 0,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0x36C92256AbbC4a60eCe681680a59057b97E57AbD
        });
    }

           
    function getOrCreateAnvilEthConfig() public returns(NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)){
            return localNetworkConfig;
        }
        
        //Deploy mocks
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(baseFee, gasprice, mockWeiPerUint);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorMock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,
            subscriptionID: 0,
            link: address(linkToken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });

        return localNetworkConfig;
    }
}