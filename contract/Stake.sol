pragma solidity ^0.8.7;

//import openzeppelin standards
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";


interface vault{
    function punishStaking(uint256 _amount) external;
}
// File: Turnstile.sol, used for register CSR in the future.
interface Turnstile {
    function register(address) external returns(uint256);
}

/**
 * @dev Implementation of a vault to deposit LP for yield optimizing.
 * This is the contract that receives LP funds and that users interface with.
 * The yield optimizing strategy itself is implemented in a separate 'Y2RStrategy.sol' contract.
 */
contract Stake is ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    bool CSRed = false;


    IERC20Upgradeable Y2Rtoken;

    mapping(address=>uint256) depositTime;
    mapping(address=>uint256) totalDeposit;

    //in case hackers stealing our contract.
    address creator;
    address strategist;

    uint256 public withdrawDelay = 6*30*24*60*60;
    uint256 public punishRate = 50;
    uint256 MAX_BPS = 1000;

    event StakingInitialized(
        IERC20Upgradeable Y2Rtoken,
        string name,
        string symbol,
        uint256 punishRate_,
        uint256 _withdrawDelay
    );
    //When CSR is registered, this event is triggered.
    event alreadyCSRed(address CSRAddress);

    constructor(){
        creator = msg.sender;
    }

    function initializeStaking(
        IERC20Upgradeable _token,
        string memory _name,
        string memory _symbol,
        address _strategist
    ) public initializer {
        require(msg.sender == creator);
        __ERC20_init(_name, _symbol);
        __Ownable_init();
        Y2Rtoken = _token;
        strategist = _strategist;
        Y2Rtoken.safeApprove(address(Y2Rtoken), 2**256-1);
        emit StakingInitialized(Y2Rtoken, _name, _symbol, punishRate, withdrawDelay);
    }

    function change2CSR(address CSRadd) external nonReentrant{
        assert(msg.sender == owner());
        assert(!CSRed);
        Turnstile turnstile  = Turnstile(CSRadd);
        turnstile.register(strategist);
        emit alreadyCSRed(CSRadd);
    }


    function want() public view returns (IERC20Upgradeable) {
        return Y2Rtoken;
    }

    function balance() public view returns (uint) {
        return want().balanceOf(address(this));
    }

    function getPricePerFullShare() public view returns (uint256) {
        return totalSupply() == 0 ? 1e18 : balance() * 1e18 / totalSupply();
    }

    function depositAll() external{
        deposit(want().balanceOf(msg.sender));
    }

    function deposit(uint _amount) public nonReentrant {
        //WARNING: Once a user deposits new funds, the time is renewed (which means the deposited funds need to wait for another withdarwDelay)
        if(_amount > 0){
            if(depositTime[msg.sender] + withdrawDelay <= block.timestamp && balanceOf(msg.sender) > 0){
                //if deposited funds are already able to be withdrawn, withdraw first.
                withdraw(balanceOf(msg.sender));
            }
            depositTime[msg.sender] = block.timestamp;

            uint256 _pool = balance();
            want().safeTransferFrom(msg.sender, address(this), _amount);
            uint256 _after = balance();
            _amount = _after - _pool; // Additional check for deflationary tokens
            uint256 shares = 0;
            if (totalSupply() == 0) {
                shares = _amount;
            } else {
                shares = (_amount * totalSupply()) / _pool;
            }
            _mint(msg.sender, shares);
            // in case a user transfer vY2Rtoken to another in order to withdraw.
            totalDeposit[msg.sender] += shares;
        }
    }


    /**
     * @dev A helper function to call withdraw() with all the sender's funds.
     */
    function withdrawAll() external {
        withdraw(balanceOf(msg.sender));
    }

    /**
     * @dev Function to exit the system. The vault will withdraw the required tokens
     * from the strategy and pay up the token holder according to the PricePerShare.
     */
    function withdraw(uint256 _shares) public {
        assert(depositTime[msg.sender] + withdrawDelay <= block.timestamp);
        assert(totalDeposit[msg.sender] >= _shares);

        uint256 r = (balance() * _shares) / totalSupply();
        totalDeposit[msg.sender] -= _shares;
        _burn(msg.sender, _shares);
        want().safeTransfer(msg.sender, r);

    }

    function withdrawPunish(uint256 _shares) public {
        assert(totalDeposit[msg.sender] > _shares);
        assert(block.timestamp < depositTime[msg.sender] + withdrawDelay);

        uint256 r = (balance() * _shares) / totalSupply();
        uint256 toPunish = r * (punishRate * (withdrawDelay + depositTime[msg.sender] - block.timestamp ) / withdrawDelay ) / MAX_BPS;
        assert(r > toPunish);
        r = r - toPunish;
        totalDeposit[msg.sender] -= _shares;
        _burn(msg.sender, _shares);
        vault(address(Y2Rtoken)).punishStaking(toPunish);
        want().safeTransfer(msg.sender, r);
    }

    function changeWithdrawDelay(uint256 delay) external{
        require(msg.sender == strategist || msg.sender == creator);
        withdrawDelay = delay;
    }
    /**
     * @dev Rescues random funds stuck that the strat can't handle.
     * @param _token address of the token to rescue.
     */
    function inCaseTokensGetStuck(address _token) external onlyOwner {
        require(_token != address(want()), "!token");

        uint256 amount = IERC20Upgradeable(_token).balanceOf(address(this));
        IERC20Upgradeable(_token).safeTransfer(owner(), amount);
    }


    function transfer(address to, uint256 amount) public override returns (bool) {
        // in case anyone wants to transfer vY2Rtoken.
        assert(false);
    }
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        // in case anyone wants to transfer vY2Rtoken.
        assert(false);
    }
}