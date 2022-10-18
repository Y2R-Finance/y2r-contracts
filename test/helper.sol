// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../contracts/StrategyY2R.sol";
import {Y2RVaultV7, IStrategyV7, IERC20Upgradeable} from "../contracts/Vault.sol";
import {Stake} from "../contracts/Stake.sol";

abstract contract Wcanto {
    function deposit() virtual external payable;
}
contract helper{
    
    address usdc = 0x80b5a32E4F032B2a058b4F29EC95EEfEEB87aDcd;
    address note = 0x4e71A2E537B7f9D9413D3991D37958c0b5e1e503;
    address pool = 0x3C96dCfd875253A37acB3D2B102b6f328349b16B;
    address lp = 0x1D20635535307208919f0b67c3B2065965A85aA9;
    address wcanto = 0x826551890Dc65655a0Aceca109aB11AbDbD7a07B;
    IUniswapRouter router = IUniswapRouter(0xa252eEE9BDe830Ca4793F054B506587027825a8e);
    address[] public outputToWantRoute;
    IUniswapRouter.route[] public temppath;
    Turnstile turnstile = Turnstile(0x0a9C3B30d5f9Bc75a1d059581ceFAe473E2432a5);

    Y2RVaultV7 public vault;
    StrategyY2R public strat;
    Stake public StakeCon;

    constructor() payable {
        vault = new Y2RVaultV7();
        StakeCon =new Stake();
        strat =new StrategyY2R(wcanto, pool, lp, address(vault), address(router), msg.sender, address(wcanto), address(note), msg.sender, address(StakeCon));
        vault.initializeY2RVaultV7(IStrategyV7(address(strat)), "myToken", "mToken", 0, address(StakeCon));
        StakeCon.initializeStaking(IERC20Upgradeable(address(vault)),"veY2RToken", "veY2R", msg.sender);
    }

    function swap() external{
        Wcanto(wcanto).deposit{value: 990*(10**18)}();
        IERC20(wcanto).approve(address(router), 2**256-1);
        IERC20(usdc).approve(address(router), 2**256-1);
        IERC20(note).approve(address(router), 2**256-1);
        IERC20(lp).approve(address(router), 2**256-1);
        IERC20(pool).approve(address(router), 2**256-1);
        IERC20(wcanto).approve(address(vault), 2**256-1);
        IERC20(usdc).approve(address(vault), 2**256-1);
        IERC20(note).approve(address(vault), 2**256-1);
        IERC20(lp).approve(address(vault), 2**256-1);
        IERC20(pool).approve(address(vault), 2**256-1);
        IERC20(address(vault)).approve(address(StakeCon), 2**256-1);
        router.swapExactTokensForTokensSimple(IERC20(wcanto).balanceOf(address(this))/2, 0,wcanto,note,false, address(this), block.timestamp);
        // router.swapExactTokensForTokensSimple(48353702589267482379, 0,note,usdc,true, address(this), block.timestamp);
        router.addLiquidity(wcanto, note, false, IERC20(wcanto).balanceOf(address(this)),NOTEbal(),0, 0, address(this), block.timestamp);

        IERC20(lp).transfer(msg.sender, IERC20(lp).balanceOf(address(this)));
        

        // strat.harvest();
    }

    function times() public view returns (uint256){
        return block.timestamp;
    }
    function withd(uint256 amount) public{
        vault.withdraw(amount);
    }
    function harvesting() public{
        strat.harvest();
    }
    function testVault(uint256 amount) public {
        vault.deposit(amount);
    }


    function testStakeDeposit() public{
        StakeCon.depositAll();
    }
    function testStakeWithdraw() public{
        StakeCon.withdrawAll();
    }
    function USDCbal() public view returns(uint256){
        return IERC20(usdc).balanceOf(address(this));
    }
    function NOTEbal() public view returns(uint256){
        return IERC20(note).balanceOf(address(this));
    }
    function WCANTOBal() public view returns (uint256){
        return IERC20(wcanto).balanceOf(address(this));
    } 
    function rewardings() public view returns (uint256){
        return IERC20(lp).balanceOf(msg.sender);
    } 
    function LPBal() public view returns (uint256){
        return IERC20(lp).balanceOf(address(this));
    } 



}
