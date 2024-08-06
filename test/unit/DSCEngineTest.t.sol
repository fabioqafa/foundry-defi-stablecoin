// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dscEngine;
    HelperConfig config;
    address ethUsdPriceFeed;
    address btcUsdPriceFeed;
    address weth;

    address public USER = makeAddr("user");
    uint256 public amountToMint = 100 ether;
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;

    //liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

    event CollateralRedeemed(
        address indexed redemeedFrom, address indexed redemeedTo, address indexed token, uint256 amount
    );

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dscEngine, config) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = config.activeNetworkConfig();

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
    }

    ///////////////////////
    // Constructor Tests //
    ///////////////////////
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function testRevertConstructorArguments() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    /////////////////
    // Price Tests //
    /////////////////

    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18;
        uint256 expectedUsd = 30000e18;
        uint256 actualUsd = dscEngine.getUsdValue(weth, ethAmount);
        assertEq(actualUsd, expectedUsd);
    }

    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether;
        // Mock price $2000 / ETH
        uint256 expectedWeth = 0.05 ether;
        uint256 actualWeth = dscEngine.getTokenAmountFromUsd(weth, usdAmount);

        assertEq(actualWeth, expectedWeth);
    }

    /////////////////////////////
    // depositCollateral Test //
    /////////////////////////////
    function testRevertsIfCOllateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertWithUnapprovedCollateral() public {
        ERC20Mock token = new ERC20Mock("TOKEN", "TKN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__TokenNotAllowed.selector);
        dscEngine.depositCollateral(address(token), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    modifier depositedCollateral() {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        _;
    }

    function testCanDepositCollateralAndGetAccountInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
        uint256 expectedTotalDscMinted = 0;
        uint256 expectedDepositAmount = dscEngine.getTokenAmountFromUsd(weth, collateralValueInUsd);

        assertEq(totalDscMinted, expectedTotalDscMinted);
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount);
    }

    function testEventFiredAfterDeposit() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectEmit();
        emit CollateralDeposited(USER, weth, AMOUNT_COLLATERAL);
        dscEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    ///////////////////////////
    // redeemCollateral Test //
    ///////////////////////////
    function testRevertsIfCollateralIsZero() public {
        vm.startPrank(USER);
        //ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.redeemCollateral(weth, 0);
        vm.stopPrank();
    }

    function testCanRedeemCollateralAndGetAccountInfo() public depositedCollateral {
        vm.startPrank(USER);
        dscEngine.redeemCollateral(weth, AMOUNT_COLLATERAL / 2);
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
        uint256 expectedDscMinted = 0;
        uint256 expectedCollateralValueInUsd =
            dscEngine.getUsdValue(weth, dscEngine.getCollateralBalanceOfUser(USER, weth));
        assertEq(totalDscMinted, expectedDscMinted);
        assertEq(collateralValueInUsd, expectedCollateralValueInUsd);
    }

    function testEventFiredAfterRedeem() public depositedCollateral {
        vm.startPrank(USER);

        vm.expectEmit();
        emit CollateralRedeemed(USER, USER, weth, AMOUNT_COLLATERAL / 2);
        dscEngine.redeemCollateral(weth, AMOUNT_COLLATERAL / 2);
        vm.stopPrank();
    }

    //////////////////////////////////////
    // depositCollateralAndMintDsc Test //
    //////////////////////////////////////

    //Minting is expected to fail when no collateral is deposited
    // meaning that the health factor is broken
    function testRevertsIfMintedDscBreaksHealthFactor() public {
        (, int256 price,,,) = MockV3Aggregator(ethUsdPriceFeed).latestRoundData();
        amountToMint =
            (AMOUNT_COLLATERAL * (uint256(price) * dscEngine.getAdditionalFeedPrecision())) / dscEngine.getPrecision();
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);
        uint256 expectedHealthFactor =
            dscEngine.calculateHealthFactor(amountToMint, dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL));
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountToMint);

        vm.stopPrank();
    }

    function testDepositCollateralAndMintDsc() public {
        //Amount to mint is going to be half of the collateral deposited
        // This means that the health factor will be exactly one.
        amountToMint = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL) / 2;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);

        dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountToMint);
        uint256 actualHealthFactor = dscEngine.getHealthFactor(USER);
        uint256 expectedHealthFactor = 1e18;
        vm.stopPrank();
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
        uint256 expectedCollateralValueInUsd = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL);
        //assertEq(actualValue, expectedValue);
        assertEq(totalDscMinted, amountToMint);
        assertEq(collateralValueInUsd, expectedCollateralValueInUsd);
        assertEq(actualHealthFactor, expectedHealthFactor);
    }

    //////////////////
    // burnDsc Test //
    //////////////////
    function testRevertsIfUserBurnsZeroDsc() public {
        uint256 amountToBurn = 0;
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dscEngine.burnDsc(amountToBurn);
        vm.stopPrank();
    }

    function testRevertsIfUserBurnsMoreThanBalance() public {
        uint256 amountToBurn = 10;
        vm.startPrank(USER);
        vm.expectRevert();
        dscEngine.burnDsc(amountToBurn);
        vm.stopPrank();
    }

    function testBurnDsc() public {
        //To burn, first need to mint and have a collateral
        amountToMint = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL) / 2;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);

        dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountToMint);
        (uint256 totalDscMintedBeforeBurn, uint256 collateralValueInUsdBeforeBurn) =
            dscEngine.getAccountInformation(USER);

        dsc.approve(address(dscEngine), amountToMint / 2);
        dscEngine.burnDsc(amountToMint / 2);
        (uint256 totalDscMintedAfterBurn, uint256 collateralValueInUsdAfterBurn) = dscEngine.getAccountInformation(USER);
        assertEq(totalDscMintedAfterBurn, totalDscMintedBeforeBurn - amountToMint / 2);
        //Collateral value should remain unchanged
        assertEq(collateralValueInUsdAfterBurn, collateralValueInUsdBeforeBurn);
    }

    /////////////////////////////////
    // redeemCollateralForDsc Test //
    ////////////////////////////////

    function testRedeemCollateralForDscHealthFactorBroken() public {
        amountToMint = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL) / 2;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);

        dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountToMint);
        (uint256 totalDscMinted,) = dscEngine.getAccountInformation(USER);

        dsc.approve(address(dscEngine), totalDscMinted);
        uint256 dscAmountToBurn = 1 ether;
        uint256 amountLeft = amountToMint - dscAmountToBurn;
        uint256 collateralAmountToRedeem = 5 ether;
        uint256 collateralLeft = AMOUNT_COLLATERAL - collateralAmountToRedeem;
        uint256 expectedHealthFactor =
            dscEngine.calculateHealthFactor(amountLeft, dscEngine.getUsdValue(weth, collateralLeft));
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__BreaksHealthFactor.selector, expectedHealthFactor));
        dscEngine.redeemCollateralForDsc(weth, collateralAmountToRedeem, dscAmountToBurn);

        vm.stopPrank();
    }

    function testRedeemCollateralForDsc() public {
        //First user needs to deposit and mint dsc
        amountToMint = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL) / 2;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);

        dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountToMint);
        (uint256 totalDscMinted,) = dscEngine.getAccountInformation(USER);

        dsc.approve(address(dscEngine), totalDscMinted);
        dscEngine.redeemCollateralForDsc(weth, AMOUNT_COLLATERAL, totalDscMinted);

        (uint256 totalDscMintedAfter, uint256 collateralValueInUsd) = dscEngine.getAccountInformation(USER);
        assertEq(totalDscMintedAfter, 0);
        assertEq(collateralValueInUsd, 0);
    }

    //////////////////
    // liquidate Test //
    //////////////////

    function testLiquidate() public {
        amountToMint = dscEngine.getUsdValue(weth, AMOUNT_COLLATERAL) / 2;
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dscEngine), AMOUNT_COLLATERAL);

        dscEngine.depositCollateralAndMintDsc(weth, AMOUNT_COLLATERAL, amountToMint);
        uint256 userHealthFactorBefore = dscEngine.getHealthFactor(USER);
        int256 ethUsdUpdatedPrice = 1000e8;
        MockV3Aggregator(ethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        uint256 userHealthFactorAfter = dscEngine.getHealthFactor(USER);
        // Here we check that the price has indeed gone down and the user health factor is lower
        // and also below the threshold
        assert(userHealthFactorAfter < userHealthFactorBefore);
        assert(userHealthFactorAfter < dscEngine.getMinHealthFactor());
        (, uint256 collateralValueInUsdUserBefore) =
            dscEngine.getAccountInformation(USER);

        ERC20Mock(weth).mint(liquidator, collateralToCover);
        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(dscEngine), collateralToCover);
        dscEngine.depositCollateralAndMintDsc(weth, collateralToCover, amountToMint);
        uint256 liquidatorBalanceBefore = dsc.balanceOf(liquidator);
        dsc.approve(address(dscEngine), amountToMint);
        dscEngine.liquidate(weth, USER, amountToMint);
        vm.stopPrank();
        (uint256 totalDscMintedUser, uint256 collateralValueInUsdUser) = dscEngine.getAccountInformation(USER);

        assertEq(totalDscMintedUser, 0);
        assertEq(collateralValueInUsdUser, 0);
        assertEq(dsc.balanceOf(liquidator), liquidatorBalanceBefore - amountToMint);
        uint256 expectedWethBalance = ERC20Mock(weth).balanceOf(liquidator);
        uint256 expectedUsdValue = dscEngine.getTokenAmountFromUsd(weth, collateralValueInUsdUserBefore);
        assertEq(
            expectedWethBalance, expectedUsdValue
        );
    }
}
