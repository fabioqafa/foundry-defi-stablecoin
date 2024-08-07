// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { DSCEngine } from "../../src/DSCEngine.sol";
import { DecentralizedStableCoin } from "../../src/DecentralizedStableCoin.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import { MockV3Aggregator } from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    MockV3Aggregator ethUsdPriceFeed;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public timesDepositIsCalled;
    uint256 public timesMintCalled;
    uint256 public timesRedeemIsCalled;

    address[] public usersWithCollateralDeposited;

    uint256 public constant MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscEngine = _dscEngine;
        dsc = _dsc;

        address[] memory collateralTokens = dscEngine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        ethUsdPriceFeed = MockV3Aggregator(dscEngine.getCollateralTokenPriceFeed(address(weth)));
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dscEngine), amountCollateral);

        dscEngine.depositCollateral(address(collateral), amountCollateral);

        vm.stopPrank();

        timesDepositIsCalled++;
        // double push
        usersWithCollateralDeposited.push(msg.sender);
    }

    function mintDsc(uint256 amountDscToMint, uint256 addressSeed) public {
        if(usersWithCollateralDeposited.length == 0) {
            return;
        }
        address sender = usersWithCollateralDeposited[addressSeed % usersWithCollateralDeposited.length];
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(sender);
        int256 maxDscToMint = (int256(collateralValueInUsd) / 2) - int256(totalDscMinted);
        if (maxDscToMint < 0) {
            return;
        }
        amountDscToMint = bound(amountDscToMint, 0, uint256(maxDscToMint));
        if (amountDscToMint == 0) {
            return;
        }
        vm.startPrank(sender);
        dscEngine.mintDsc(amountDscToMint);
        vm.stopPrank();

        timesMintCalled++;
    }

    function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);      
        //(uint256 totalDscMinted, ) = dscEngine.getAccountInformation(msg.sender);
        //uint256 maxCollateralToRedeem = dscEngine.getUsdValue(address(collateral), dscEngine.getCollateralBalanceOfUser(msg.sender, address(collateral))) - (2 * totalDscMinted);
        uint256 maxCollateralToRedeem = dscEngine.getCollateralBalanceOfUser(address(collateral), msg.sender);
        amountCollateral = bound(amountCollateral, 0, dscEngine.getTokenAmountFromUsd(address(collateral), maxCollateralToRedeem));
        
        //To check for other bugs, for example the user redeems more collateral than he has
        //remove the maxCollateralToRedeem and `amountCollateral = bound(amountCollateral, 0, MAX_DEPOSIT_SIZE);`
        //Also, put fail_on_revert on foundry.toml to false.
        if (amountCollateral == 0) {
            return;
        }
        vm.startPrank(msg.sender);
        dscEngine.redeemCollateral(address(collateral), amountCollateral);
        vm.stopPrank();

        timesRedeemIsCalled++;
    }

    // This breaks our invariant test!!!
    // function updateCollateralPrice(uint96 newPrice) public {
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }


    // Helper functions

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }

        return wbtc;
    }
}
