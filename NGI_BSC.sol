// SPDX-License-Identifier: MIT

/**
 * @author : Nebula.fi
 * wBTC-wETH
 */

// Posibilidades: BTC ETH BNB ADA DOT ATOM LINK LTC MATIC AVAX XRP 

pragma solidity ^0.8.7;
//modificar IMPORT
import "../../utils/ChainId.sol";
import "./NGISplitter.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract BSC_GenesisIndex is ERC20Upgradeable, OwnableUpgradeable, PausableUpgradeable, ChainId, NGISplitter {
    event Mint(address indexed from, uint256 wBtcIn, uint256 wEthIn,uint256 indexed amount);
    event Burn(address indexed from, uint256 usdcIn, uint256 indexed amount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor () {
        _disableInitializers();
    }



    function initialize() public initializer{
        __ERC20_init("Nebula Genesis Index - BSC", "NGI_BSC");
        __Ownable_init();
        __Pausable_init();
        tokens = [
            0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d, //[0] => USDC
            0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c, //[1] => BTCB
            0x2170Ed0880ac9A755fd29B2688956BD959F933F8, // [2] => ETH
        ];
        multipliers = [1, 1, 1];
        marketCapWeigth = [0, 7400, 2600];
        uniV3 = ISwapRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E); // PancakeSwap_router

        addressRouting = [0x10ED43C718714eb63d5aA57B78B54704E256024E];

        priceFeeds = [
            AggregatorV3Interface(0x50834f3163758fcc1df9973b6e91f0f0f0434ad3), // USDC
            AggregatorV3Interface(0x264990fbd0a4796a3e3d8e37c4d5f87a3aca5ebf), // BTCB
            AggregatorV3Interface(0x9ef1b8c0e4f7dc8bf5719ea496883dc6401d5b2e), // wETH
        ];
       

    }

    /**
     * @notice Returns the price of the index
     * wETH/usdc * 0.4 + wBTC/usdc * 0.45 + ARB/usdc * 0.15
     */
    function getVirtualPrice() public view returns (uint256) {
        return (((getLatestPrice(1) * 7400) / 10000) + ((getLatestPrice(2) * 2600) / 10000)
    }

    /**
     * @notice function to buy 74% wBTC and 26% wETH with usdc
     * @param tokenIn : the token to deposit, must be a component of the index(0,1,2)
     * @param amountIn : token amount to deposit
     * @param recipient : recipient of the NGI tokens
     * @return shares : amount of minted tokens
     */
    function deposit(uint8 tokenIn, uint256 amountIn, address recipient)
        public
        whenNotPaused
        returns (uint256 shares)
    {
        require(tokenIn < 3, "token >=3");
        require(amountIn > 0, "dx=0");
        uint256 dywBtc;
        uint256 dywEth;
        uint8 i = tokenIn;

        TransferHelper.safeTransferFrom(tokens[i], msg.sender, address(this), amountIn);

        (uint256 amountForBtc, uint256 amountForEth) = ((amountIn * 7400) / 10000, (amountIn * 2600) / 10000);

        approveAMM(i, amountIn);
        dywBtc = swapWithParams(i, 1, amountForBtc);
        dywEth = swapWithParams(i, 2, amountForEth;

        _mint(
            recipient,
            shares = ((dywBtc * multipliers[1] * getLatestPrice(1)) + (dywEth * multipliers[2] * getLatestPrice(2)))
                / getVirtualPrice()
        );
        emit Mint(recipient, dywBtc, dywEth, shares);
    }

    /**
     * @notice function to buy 74% wBTC + 26% wETH with usdc choosing a custom AMM split, previously calculated off-chain
     * @param tokenIn : the token to deposit, must be a component of the index(0,1,2)
     * @param amountIn : amount of the token to deposit
     * @param percentagesWBTCSplit : percentages of the token to exchange in each dex to buy WBTC
     * @param percentagesWETHSplit : percentages of the token to exchange in each dex to buy WETH
     * @param recipient : recipient of the NST
     * @return shares : amount of minted tokens
     */


    /**
     * @notice Function to liquidate wETH and wBTC positions for usdc
     * @param NSTin : the number of indexed tokens to burn 
     * @param percentagesWBTCSplit : percentages of the token to exchange in each dex to buy WBTC
     * @param percentagesWETHSplit : percentages of the token to exchange in each dex to buy WETH
     * @param recipient : recipient of the USDC
     * @return usdcOut : final usdc amount to withdraw after slippage and fees
     */

    function withdrawUsdcCustom(
        uint256 NSTin,
        uint16[5] calldata percentagesWBTCSplit,
        uint16[5] calldata percentagesWETHSplit,
        address recipient
    ) external whenNotPaused returns (uint256 usdcOut) {
        require(NSTin > 0, "dx=0");
        require(_getTotal(percentagesWBTCSplit) == 10000 && _getTotal(percentagesWETHSplit) == 10000, "!=100%");

        uint256 balanceWBtc = IERC20(tokens[1]).balanceOf(address(this));
        uint256 balanceWEth = IERC20(tokens[2]).balanceOf(address(this));
        uint256 wBtcIn = balanceWBtc * NSTin / totalSupply();
        uint256 wEthIn = balanceWEth * NSTin / totalSupply();
        uint256[5] memory btcSplits;
        uint256[5] memory ethSplits;

        for (uint8 index = 0; index < 5;) {
            btcSplits[index] = wBtcIn * percentagesWBTCSplit[index] / 10000;
            ethSplits[index] = wEthIn * percentagesWETHSplit[index] / 10000;
            unchecked {
                ++index;
            }
        }
        _burn(msg.sender, NSTin);

        approveAMM(1, wBtcIn, 5);
        approveAMM(2, wEthIn, 5);
        TransferHelper.safeTransfer(
            tokens[0],
            recipient,
            usdcOut = swapWithParamsCustom(1, 0, btcSplits) + swapWithParamsCustom(2, 0, ethSplits)
        );
        emit Burn(recipient, usdcOut, NSTin);
    }

    function _getTotal(uint16[5] memory _params) private pure returns (uint16) {
        uint256 len = _params.length;
        uint16 total = 0;
        for (uint8 i = 0; i < len;) {
            uint16 n = _params[i];
            if (n != 0) {
                total += n;
            }
            unchecked {
                ++i;
            }
        }
        return total;
    }

    //////////////////////////////////
    // SPECIAL PERMISSION FUNCTIONS//
    /////////////////////////////////

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

   
}
