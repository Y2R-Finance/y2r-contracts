// SPDX-License-Identifier: MIT

pragma solidity^ 0.8.0;


interface IBaseV1Factory {
    function allPairsLength() external view returns (uint);
    function isPair(address pair) external view returns (bool);
    function pairCodeHash() external pure returns (bytes32);
    function getPair(address tokenA, address token, bool stable) external view returns (address);
    function createPair(address tokenA, address tokenB, bool stable) external returns (address);
}
interface CToken{

}
interface IBaseV1Pair {
    function transferFrom(address src, address dst, uint amount) external returns (bool);
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function burn(address to) external returns (uint amount0, uint amount1);
    function mint(address to) external returns (uint liquidity);
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
    function getAmountOut(uint, address) external view returns (uint);
    function current(address tokenIn, uint amountIn) external view returns(uint);
    function token0() external view returns(address);
    function token1() external view returns(address);
    function stable() external view returns(bool);
    function _k(uint x, uint y) external view returns(uint);
    //LP token pricing
    function sampleReserves(uint points, uint window) external view returns(uint[] memory, uint[] memory);
    function sampleSupply(uint points, uint window) external view returns(uint[] memory);
    function sample(address tokenIn, uint amountIn, uint points, uint window) external view returns(uint[] memory);
    function quote(address tokenIn, uint amountIn, uint granularity) external view returns(uint);
}

interface IWCANTO {
    function deposit() external payable ;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external ;
}

interface ICErc20 {
    function underlying() external view returns(address);
}

contract IUniswapRouter{
    //address of Unitroller to obtain prices with respect to USDC
    address public note;  
    //address of Comptroller, so that price of note may be set to 1 in Account Liquidity calculations
    address public Comptroller;

    address public admin;

    struct route {
        address from;
        address to;
        bool stable;
    }

    address public factory;
    IWCANTO public wcanto;
    uint internal constant MINIMUM_LIQUIDITY = 10**3;
    bytes32 pairCodeHash;

    mapping(address => bool) public isStable;

    error SenderNotAdmin(address sender, address admin);



    // admin for setting the stable pairs
    function setAdmin(address admin_) external {
    }

    function sortTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address tokenA, address tokenB, bool stable) public view returns (address pair) {
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quoteLiquidity(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address tokenA, address tokenB, bool stable) public view returns (uint reserveA, uint reserveB) {
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountOut(uint amountIn, address tokenIn, address tokenOut) external view returns (uint amount, bool stable) {
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(uint amountIn, route[] memory routes) public view returns (uint[] memory amounts) {

    }

    function isPair(address pair) public view returns (bool) {
    }

    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired
    ) external view returns (uint amountA, uint amountB, uint liquidity) {
    }

    function quoteRemoveLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint liquidity
    ) public view returns (uint amountA, uint amountB) {
    }


    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external  returns (uint amountA, uint amountB, uint liquidity) {
    }

    function addLiquidityCANTO(
        address token,
        bool stable,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountCANTOMin,
        address to,
        uint deadline
    ) external payable   returns (uint amountToken, uint amountCANTO, uint liquidity) {
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public   returns (uint amountA, uint amountB) {
    }

    function removeLiquidityCANTO(
        address token,
        bool stable,
        uint liquidity,
        uint amountTokenMin,
        uint amountCANTOMin,
        address to,
        uint deadline
    ) public   returns (uint amountToken, uint amountCANTO) {
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        bool stable,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB) {
    }

    function removeLiquidityCANTOWithPermit(
        address token,
        bool stable,
        uint liquidity,
        uint amountTokenMin,
        uint amountCANTOMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountCANTO) {
    }
    
    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, route[] memory routes, address _to) internal virtual {
    }

    function swapExactTokensForTokensSimple(
        uint amountIn,
        uint amountOutMin,
        address tokenFrom,
        address tokenTo,
        bool stable,
        address to,
        uint deadline
    ) external   returns (uint[] memory amounts) {
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        route[] calldata routes,
        address to,
        uint deadline
    ) external   returns (uint[] memory amounts) {
    }

    function swapExactCANTOForTokens(uint amountOutMin, route[] calldata routes, address to, uint deadline)
    external
    payable
    
    returns (uint[] memory amounts)
    {
        require(routes[0].from == address(wcanto), "BaseV1Router: INVALID_PATH");
        amounts = getAmountsOut(msg.value, routes);
        require(amounts[amounts.length - 1] >= amountOutMin, "BaseV1Router: INSUFFICIENT_OUTPUT_AMOUNT");
        wcanto.deposit{value: amounts[0]}();
        assert(wcanto.transfer(pairFor(routes[0].from, routes[0].to, routes[0].stable), amounts[0]));
        // _swap(amounts, routes, to);
    }
    
    function swapExactTokensForCANTO(uint amountIn, uint amountOutMin, route[] calldata routes, address to, uint deadline)
    external
    
    returns (uint[] memory amounts)
    {

    }

    function UNSAFE_swapExactTokensForTokens(
        uint[] memory amounts,
        route[] calldata routes,
        address to,
        uint deadline
    ) external   returns (uint[] memory) {
    }

    function _safeTransferCANTO(address to, uint value) internal {
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
    }

    function setStable(address underlying) external returns (uint) {
    }

    //returns the underlying price of the assets as a mantissa (scaled by 1e18)
    function getUnderlyingPrice(CToken ctoken) external   view returns(uint) {
      
    }
    
}