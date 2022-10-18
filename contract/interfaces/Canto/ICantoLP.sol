pragma solidity ^0.8.0;
interface ICantoLP{
    function mint(uint256 mintAmount) external returns (uint256);
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256);
    function redeem(uint256 redeemAmount) external returns (uint256);
    function balanceOfUnderlying(address account) external view returns (uint256);
    function exchangeRateCurrent() external view returns (uint);
    function balanceOf(address add) external view returns (uint256);
}