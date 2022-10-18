// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./StratManager.sol";

abstract contract FeeManager is StratManager {
    uint constant public rewardFee = 45;
    uint constant public MAX_FEE = 1000;
    uint constant public MAX_CALL_FEE = 111;
    uint constant public MAX_uint256 = 115792089237316195423570985008687907853269984665640564039457584007913129639935;
    uint constant public WITHDRAWAL_FEE_CAP = 50;
    uint constant public WITHDRAWAL_MAX = 10000;

    uint public withdrawalFee = 0;
    uint public callFee = 5;

    function setCallFee(uint256 _fee) public onlyManager {
        require(_fee <= MAX_CALL_FEE, "!cap");
        
        callFee = _fee;
    }

    function setWithdrawalFee(uint256 _fee) public onlyManager {
        require(_fee <= WITHDRAWAL_FEE_CAP, "!cap");

        withdrawalFee = _fee;
    }
}