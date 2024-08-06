// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IDSCEngine {
    // External Functions
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external;

    function redeemCollateralForDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToBurn
    ) external;

    function liquidate(
        address collateral,
        address user,
        uint256 debtToCover
    ) external;

    function burnDsc(uint256 amount) external;

    function redeemCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) external;

    // Public Functions
    function mintDsc(uint256 amountDscToMint) external;

    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) external;

    function calculateHealthFactor(
        uint256 totalDscMinted,
        uint256 collateralValueInUsd
    ) external pure returns (uint256);

    function getHealthFactor(address user) external view returns (uint256);

    function getCollateralBalanceOfUser(
        address user,
        address token
    ) external view returns (uint256);

    function getAccountInformation(
        address user
    ) external view returns (uint256 totalDscMinted, uint256 collateralValueInUsd);

    function getDSC() external view returns (address);

    function getAdditionalFeedPrecision() external pure returns (uint256);

    function getPrecision() external pure returns (uint256);

    function getLiquidationThreshold() external pure returns (uint256);

    function getLiquidationPrecision() external pure returns (uint256);

    function getLiquidatorBonus() external pure returns (uint256);

    function getMinHealthFactor() external pure returns (uint256);

    function getAccountCollateralValue(
        address user
    ) external view returns (uint256 totalCollateralValueInUsd);

    function getUsdValue(address token, uint256 amount) external view returns (uint256);

    function getTokenAmountFromUsd(
        address token,
        uint256 usdAmountInWei
    ) external view returns (uint256);
}
