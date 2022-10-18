pragma solidity ^0.8.0;
interface IComptroller{
    function claimComp(address holder) external;
    function pendingComptrollerImplementation() external view returns(address);
}


