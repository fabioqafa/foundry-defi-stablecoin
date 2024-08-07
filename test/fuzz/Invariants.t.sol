// SPDX-License-Identifier: MIT

//This is where the invariants/properties of the smart contract are stored

//Before starting invariant starting, developer should know what are the invariants/properties

// 1. The total supply of DSC should always be less than the total value of collateral in USD
// 2. Getter view functions should never revert <- evergreen invariant

pragma solidity ^0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { DeployDSC } from "../../script/DeployDSC.s.sol";
import { DSCEngine } from "../../src/DSCEngine.sol";
import { DecentralizedStableCoin } from "../../src/DecentralizedStableCoin.sol";
import { HelperConfig } from "../../script/HelperConfig.s.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Handler } from "./Handler.t.sol";

contract InvariantsTest is StdInvariant, Test {
    DeployDSC deployer;
    DSCEngine dscEngine;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    Handler handler;
    address weth;
    address wbtc;

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dscEngine, config) = deployer.run();
        (,, weth, wbtc,) = config.activeNetworkConfig();
        handler = new Handler(dscEngine, dsc);
        targetContract(address(handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dscEngine));
        uint256 totalWbtcDeposited = IERC20(wbtc).balanceOf(address(dscEngine));

        uint256 wethValue = dscEngine.getUsdValue(weth, totalWethDeposited);
        uint256 wbtcValue = dscEngine.getUsdValue(weth, totalWbtcDeposited);
        console.log('WETH value in USD: ', wethValue);
        console.log("WBTC value in USD: ", wbtcValue);
        console.log("DSC total supply: ", totalSupply);
        console.log("Times deposit is called: ", handler.timesDepositIsCalled());
        console.log("Times mint is called: ", handler.timesMintCalled());
        console.log("Times redeem is called: ", handler.timesRedeemIsCalled());

        assert(wethValue + wbtcValue >= totalSupply);
    }

    function invariant_gettersShouldNeverRevert() public view {
        dscEngine.getLiquidatorBonus();
        dscEngine.getPrecision();
        dscEngine.getPrecision();
    }
}
