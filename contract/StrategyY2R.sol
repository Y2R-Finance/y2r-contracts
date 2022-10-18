// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interfaces/StratManager.sol";
import "./interfaces/FeeManager.sol";

import "./interfaces/Canto/ICantoLP.sol";
import "./interfaces/Canto/IComptroller.sol";

import "./interfaces/IUniswapRouter.sol";

interface Turnstile {
    function register(address) external returns(uint256);
}
interface Vault{
    function stakeDeposit(uint _amount) external;
}
//Lending Strategy 
contract StrategyY2R is StratManager, FeeManager {
    using SafeERC20 for IERC20;

    // Tokens used
    address public output = 0x826551890Dc65655a0Aceca109aB11AbDbD7a07B;//reward token address
    address note = 0x4e71A2E537B7f9D9413D3991D37958c0b5e1e503;
    address public want;
    address public pool;
    address public token1;
    address public token2;
    address public strategist;
    address public stake;

    // Third party contracts
    address constant public comptroller = 0x5E23dC409Fc2F832f83CEc191E245A191a4bCc5C;
    Turnstile turnstile ;
    bool public onCSR;

    bool public harvestOnDeposit;
    bool public harvestOnWithdraw;
    uint256 public lastHarvest;


//events
    event StratHarvest(address indexed harvester, uint256 wantHarvested, uint256 tvl);
    event Deposit(uint256 tvl);
    event Withdraw(uint256 tvl);
    event CallerRewards(uint256 amount, address caller);
    event StakeRewards(uint256);

//constructor
    constructor(
        address _output,
        address _pool,
        address _want,
        address _vault,
        address _unirouter,
        address _keeper,
        address _token1,
        address _token2,
        address _strategist,
        address _stake
    ) StratManager(_keeper, _unirouter, _vault) public {

        require(_token1 == note || _token1 == output);
        pool = _pool;
        onCSR = false;
        want = _want;
        harvestOnDeposit = true;
        harvestOnWithdraw = false;
        output = _output;
        token1 = _token1;
        token2 = _token2;
        stake = _stake;
        strategist = _strategist;
        lastHarvest = block.timestamp;
        _giveAllowances();
    }

// external API from vault or manager
    // puts the funds to work
    function deposit() public whenNotPaused {
        uint256 wantBal = balanceOfWant();

        if (wantBal > 0) {
            ICantoLP(pool).mint(wantBal);
            emit Deposit(balanceOf());
        }
    }

    function change2CSR(address CSRaddress) external onlyManager {
        require(!onCSR);
        turnstile  = Turnstile(CSRaddress);
        turnstile.register(owner());
        onCSR = true;
    }

    function changeStrategist(address newStrategist) external {
        require(msg.sender == strategist);
        strategist = newStrategist;
    }
    /**
     * @dev Withdraws funds and sends them back to the vault. It deleverages first,
     * and then deposits again after the withdraw to make sure it mantains the desired ratio.
     * @param _amount How much {want} to withdraw.
     */
    function withdraw(uint256 _amount) external {
        require(msg.sender == vault, "!vault");

        uint256 wantBal = balanceOfWant();

        if (wantBal < _amount) {
            ICantoLP(pool).redeemUnderlying(_amount - wantBal);
            require(balanceOfWant() >= _amount, "Want Balance Less than Requested");
            wantBal = balanceOfWant();
        }

        if (wantBal > _amount) {
            wantBal = _amount;
        }

        if (tx.origin != owner() && !paused()) {
            uint256 withdrawalFeeAmount = wantBal * withdrawalFee / WITHDRAWAL_MAX;
            wantBal = wantBal - withdrawalFeeAmount;
        }

        IERC20(want).safeTransfer(vault, wantBal);
        emit Withdraw(balanceOf());        
    }
//Manager interfaces
    function withdrawFromScream() external onlyManager { 
        // Withdraw what we can from Scream 
        uint256 wantBal = IERC20(want).balanceOf(pool);
        uint256 balanceOfPool = balanceOfPool();
        if (balanceOfPool > wantBal) {
            ICantoLP(pool).redeemUnderlying(wantBal);
        } else { 
            uint256 poolBal = IERC20(pool).balanceOf(address(this));
            ICantoLP(pool).redeem(poolBal);
        }
    }

    function withdrawPartialFromScream(uint256 _amountUnderlying) external onlyManager { 
        // Withdraw what we can from Scream 
        require(balanceOfPool() >= _amountUnderlying, "more than our Scream balance");
        uint256 wantBal = IERC20(want).balanceOf(pool);
        require(wantBal >= _amountUnderlying, "not enough in Scream");
        
        ICantoLP(pool).redeemUnderlying(_amountUnderlying);
    }
//Harvest
    function beforeDeposit() external override {
        if (harvestOnDeposit) {
            require(msg.sender == vault, "!vault");
            _harvest();
        }
    }

    function beforeWithdraw() external {
        if (harvestOnWithdraw) {
            require(msg.sender == vault, "!vault");
            _harvest();
        }
    }
    //reward the person who call this. 
    function harvest() external virtual {
        _harvest();
    }

    // compounds earnings and charges performance fee
    function _harvest() internal whenNotPaused {
        if (IComptroller(comptroller).pendingComptrollerImplementation() == address(0)) {
            uint256 beforeBal = balanceOfWant();
            IComptroller(comptroller).claimComp(address(this));
            uint256 outputBal = IERC20(output).balanceOf(address(this));
            uint256 wantHarvested;
            if (outputBal > 0) {
                swapRewards();
                if(balanceOfWant() > beforeBal){
                wantHarvested = balanceOfWant() - beforeBal;
                deposit();
                }
                lastHarvest = block.timestamp;
                emit StratHarvest(msg.sender, wantHarvested, balanceOf());
            }
        } else {
            panic();
        }
    }


    function outputbal() public view returns (uint256){
        return IERC20(output).balanceOf(address(this));
    }

    // swap rewards to {want}
    function swapRewards() internal {
        uint256 toWant = IERC20(output).balanceOf(address(this));
        uint256 _before = IERC20(want).balanceOf(address(this));
        if(token1 == output){
            uint256 toSwap = toWant/2;
            uint[] memory amounts = IUniswapRouter(unirouter).swapExactTokensForTokensSimple(toSwap, 0, output, token2, false, address(this), block.timestamp);
            IUniswapRouter(unirouter).addLiquidity(token1, token2, false,IERC20(token1).balanceOf(address(this)), IERC20(token2).balanceOf(address(this)), 0, 0, address(this), block.timestamp);
        }else{
            uint[] memory amounts1 = IUniswapRouter(unirouter).swapExactTokensForTokensSimple(toWant, 0, output, note, false, address(this), block.timestamp);
            uint256 toToken2 = IERC20(note).balanceOf(address(this))/2;
            uint[] memory amounts2 = IUniswapRouter(unirouter).swapExactTokensForTokensSimple(toToken2, 0, note, token2, true, address(this), block.timestamp);
            IUniswapRouter(unirouter).addLiquidity(token1, token2, true,IERC20(token1).balanceOf(address(this)), IERC20(token2).balanceOf(address(this)), 0, 0, address(this), block.timestamp);

        }
        uint256 _after = IERC20(want).balanceOf(address(this));
        if(_after > _before){
            uint256 totalHarvest = _after - _before;
            uint256 toRewardCaller = totalHarvest * callFee / MAX_FEE;
            uint256 toRewardStake = totalHarvest * rewardFee / MAX_FEE;
            uint256 toStake = toRewardStake * IERC20(vault).balanceOf(stake) / IERC20(vault).totalSupply();
            IERC20(want).safeTransfer(tx.origin, toRewardCaller);
            emit CallerRewards(toRewardCaller, tx.origin);
            Vault(vault).stakeDeposit(toStake);
            IERC20(want).safeTransfer(strategist, toRewardStake - toStake);
            emit StakeRewards(toRewardStake);


        } 
    }

//query interfaces
    // calculate the total underlaying 'want' held by the strat.
    function balanceOf() public view returns (uint256) {
        return balanceOfWant() + balanceOfPool();
    }

    // it calculates how much 'want' this contract holds.
    function balanceOfWant() public view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    // return supply balance
    function balanceOfPool() public view returns(uint){
        return ICantoLP(pool).balanceOf(address(this));
    }

    // returns rewards unharvested and also claim all coins
    function rewardsAvailable() public returns (uint256) {
        IComptroller(comptroller).claimComp(address(this));
        return IERC20(output).balanceOf(address(this));
    }

    // called as part of strat migration. Sends all the available funds back to the vault.
    function retireStrat() external {
        require(msg.sender == vault, "!vault");

        uint256 poolBal = IERC20(pool).balanceOf(address(this));
        ICantoLP(pool).redeem(poolBal);

        uint256 wantBal = IERC20(want).balanceOf(address(this));
        IERC20(want).transfer(vault, wantBal);
    }

    // pauses deposits and withdraws all funds from third party systems.
    function panic() public onlyManager {
        uint256 poolBal = IERC20(pool).balanceOf(address(this));
        ICantoLP(pool).redeem(poolBal);
        IERC20(want).transfer(vault, IERC20(want).balanceOf(address(this)));
        pause();
    }

    function pause() public onlyManager {
        _pause();

        _removeAllowances();
    }

    function unpause() external onlyManager {
        _unpause();

        _giveAllowances();

        deposit();
    }

    function _giveAllowances() internal {

            IERC20(want).safeApprove(pool, MAX_uint256);
            IERC20(output).safeApprove(unirouter, MAX_uint256);
            IERC20(note).safeApprove(unirouter, MAX_uint256);
            if(note != token2){
                IERC20(token2).safeApprove(unirouter, MAX_uint256);
            }

            IERC20(want).safeApprove(vault, MAX_uint256);
    }

    function _removeAllowances() internal {
            IERC20(want).safeApprove(pool, 0);
            IERC20(output).safeApprove(unirouter, 0);
            IERC20(note).safeApprove(unirouter, 0);
            IERC20(token2).safeApprove(unirouter, 0);
            IERC20(want).safeApprove(vault, 0);
    }
    function inCaseTokensGetStuck(address _token) external onlyOwner {
        require(_token != address(want), "!token");

        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(vault, amount);
    }

}
