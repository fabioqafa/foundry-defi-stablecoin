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

        assert(wethValue + wbtcValue >= totalSupply);
    }

    function invariant_gettersShouldNeverRevert() public view {
        dscEngine.getLiquidatorBonus();
        dscEngine.getPrecision();
        dscEngine.getPrecision();
        dscEngine.getAccountCollateralValue(msg.sender);
        dscEngine.getAccountInformation(msg.sender);
        dscEngine.getAdditionalFeedPrecision();
        dscEngine.getCollateralBalanceOfUser(msg.sender, weth);
        dscEngine.getCollateralTokenPriceFeed(weth);
        dscEngine.getCollateralTokens();
        dscEngine.getDSC();
        dscEngine.getHealthFactor(msg.sender);
        dscEngine.getLiquidationPrecision();
        dscEngine.getLiquidationThreshold();
        dscEngine.getLiquidatorBonus();
        dscEngine.getMinHealthFactor();
        dscEngine.getPrecision();
        dscEngine.getTokenAmountFromUsd(weth, 1 ether);
        dscEngine.getUsdValue(weth, 1 ether);
    }

    function invariant_callSummary() public view {
        return handler.callSummary();
    }
}
