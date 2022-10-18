pragma solidity ^0.8.7;

//import openzeppelin standards
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// import Y2R interfaces
import "./interfaces/IStrategyV7.sol";

// File: Turnstile.sol, used for register CSR in the future.
interface Turnstile {
    function register(address) external returns(uint256);
}

/**
 * @dev Implementation of a vault to deposit LP for yield optimizing.
 * This is the contract that receives LP funds and that users interface with.
 * The yield optimizing strategy itself is implemented in a separate 'Y2RStrategy.sol' contract.
 */
contract Y2RVaultV7 is ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct StratCandidate {
        address implementation;
        uint proposedTime;
    }
    address creator;

    // The last proposed strategy to switch to.
    StratCandidate public stratCandidate;
    // The strategy currently in use by the vault.
    IStrategyV7 public strategy;
    address public Stake;
    // The minimum time it has to pass before a strat candidate can be approved.
    uint256 public approvalDelay;
    // The interface of turnstile on canto.
    Turnstile turnstile;
    // To show if the contract is registered for CSR or not.
    bool CSRed;

    //When adding a new strategy, this event is triggered.
    event NewStratCandidate(address implementation);
    // When new strategy is put to use, this event is triggered.
    event UpgradeStrat(address implementation);
    //When Vault is initialized, this event is triggered.
    event Y2RVaultV7Initialized(
        IStrategyV7 strategy,
        string name,
        string symbol,
        uint256 approvalDelay
    );
    //When CSR is registered, this event is triggered.
    event alreadyCSRed(address CSRAddress);

    constructor() {
        creator = msg.sender;
    }
    /**
     * @dev Sets the initial values of the Vault. It initializes the vault's own 'Y2R' token.
     * This token is minted when someone does a deposit. It is burned in order
     * to withdraw the corresponding portion of the underlying assets.
     * @param _strategy the address of the strategy.
     * @param _name the name of the vault token.
     * @param _symbol the symbol of the vault token.
     * @param _approvalDelay the delay before a new strat can be approved.
     */
    function initializeY2RVaultV7(
        IStrategyV7 _strategy,
        string memory _name,
        string memory _symbol,
        uint256 _approvalDelay,
        address _stake
    ) public initializer {
        assert(msg.sender == creator);
        __ERC20_init(_name, _symbol);
        strategy = _strategy;
        approvalDelay = _approvalDelay;
        __Ownable_init();
        Stake = _stake;

        emit Y2RVaultV7Initialized(strategy, _name, _symbol, approvalDelay);
    }

    function change2CSR(address CSRadd) external nonReentrant{
        assert(msg.sender == owner());
        assert(!CSRed);
        turnstile  = Turnstile(CSRadd);
        turnstile.register(owner());
        emit alreadyCSRed(CSRadd);
    }

    /**
     * @dev This function return the LP this vault want to get from users.
     */
    function want() public view returns (IERC20Upgradeable) {
        return IERC20Upgradeable(strategy.want());
    }

    /**
     * @dev It calculates the total underlying value of {want} held by the system.
     * It takes into account the vault contract balance and the strategy contract balance
     */
    function balance() public view returns (uint) {
        return want().balanceOf(address(this)) + IStrategyV7(strategy).balanceOf();
    }

    /**
     * @dev Custom logic in here for how much the vault allows to be borrowed.
     * We return 100% of tokens for now. Under certain conditions we might
     * want to keep some of the system funds at hand in the vault, instead
     * of putting them to work.
     */
    function available() public view returns (uint256) {
        return want().balanceOf(address(this));
    }

    /**
     * @dev Function for various UIs to display the current value of one of our yield tokens.
     * Returns an uint256 with 18 decimals of how much underlying asset one vault share represents.
     */
    function getPricePerFullShare() public view returns (uint256) {
        return totalSupply() == 0 ? 1e18 : balance() * 1e18 / totalSupply();
    }

    /**
     * @dev A helper function to call deposit() with all the sender's funds.
     */
    function depositAll() external{
        deposit(want().balanceOf(msg.sender));
    }

    /**
     * @dev The entrypoint of funds into the system. People deposit with this function
     * into the vault. The vault is then in charge of sending funds into the strategy.
     */
    function deposit(uint _amount) public nonReentrant {
        strategy.beforeDeposit();

        uint256 _pool = balance();
        want().safeTransferFrom(msg.sender, address(this), _amount);
        earn();
        uint256 _after = balance();
        _amount = _after - _pool; // Additional check for deflationary tokens
        uint256 shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount * totalSupply()) / _pool;
        }
        _mint(msg.sender, shares);

    }
    function stakeDeposit(uint _amount) public {
        require(msg.sender == address(strategy));

        uint256 _pool = balance() - _amount;
        want().safeTransferFrom(msg.sender, address(this), _amount);
        uint256 shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount * totalSupply()) / _pool;
        }
        _mint(Stake, shares);

    }
    /**
     * @dev Function to send funds into the strategy and put them to work. It's primarily called
     * by the vault's deposit() function.
     */
    function earn() public {
        uint _bal = available();
        want().safeTransfer(address(strategy), _bal);
        strategy.deposit();
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
        strategy.beforeWithdraw();
        uint256 r = (balance() * _shares) / totalSupply();
        _burn(msg.sender, _shares);

        uint b = want().balanceOf(address(this));
        if (b < r) {
            uint _withdraw = r - b;
            strategy.withdraw(_withdraw);
            uint _after = want().balanceOf(address(this));
            uint _diff = _after - b;
            if (_diff < _withdraw) {
                r = b + _diff;
            }
        }
        want().safeTransfer(msg.sender, r);
    }

    /** 
     * @dev Sets the candidate for the new strat to use with this vault.
     * @param _implementation The address of the candidate strategy.  
     */
    function proposeStrat(address _implementation) public onlyOwner {
        assert(address(this) == IStrategyV7(_implementation).vault());
        assert(want() == IStrategyV7(_implementation).want());
        stratCandidate = StratCandidate({
            implementation: _implementation,
            proposedTime: block.timestamp
        });
        emit NewStratCandidate(_implementation);
    }

    /** 
     * @dev It switches the active strat for the strat candidate. After upgrading, the 
     * candidate implementation is set to the 0x00 address, and proposedTime to a longer time to ensure safety.
     */
    function upgradeStrat() public onlyOwner {
        assert(stratCandidate.implementation != address(0));
        assert(stratCandidate.proposedTime + approvalDelay < block.timestamp);

        emit UpgradeStrat(stratCandidate.implementation);

        strategy.retireStrat();
        strategy = IStrategyV7(stratCandidate.implementation);
        stratCandidate.implementation = address(0);
        stratCandidate.proposedTime = 864000;

        earn();
    }

    /** 
     * @dev When a staking user wants to quit earlier than expected, punish and give the punish amount to all users by burning his Y2Rtoken.
     * It will increase the pricePerShare.
     */
    function punishStaking(uint256 _amount) public{
        assert(msg.sender == Stake);
        _burn(msg.sender, _amount);
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
}