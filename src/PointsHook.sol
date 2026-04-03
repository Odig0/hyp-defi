// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title PointsHook
 * @dev Hook de Uniswap v4 que recompensa a los usuarios que compran tokens de equipos
 * 
 * NOTA: Esta version simplificada se enfoca en la logica de recompensas.
 * En produccion, necesitarias registrar correctamente el hook en Uniswap v4.
 */

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "v4-core/types/BeforeSwapDelta.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {FootballPoints} from "./FootballPoints.sol";

contract PointsHook is IHooks, Ownable {
    // Referencia al contrato de puntos
    FootballPoints public pointsContract;
    
    // Referencia al PoolManager
    IPoolManager public poolManager;

    // Mapeo: key hash => ID del equipo en ERC-1155
    mapping(bytes32 => uint256) public poolKeyToTeamId;

    // Porcentaje de recompensa: 20%
    uint256 public constant REWARD_PERCENTAGE = 20;

    // Eventos
    event PoolRegistered(bytes32 indexed poolKeyHash, uint256 teamId);
    event RewardsAwarded(address indexed user, uint256 indexed teamId, uint256 points, uint256 ethSpent);

    /**
     * @dev Constructor del Hook
     * @param _poolManager Direccion del PoolManager de Uniswap v4
     * @param _pointsContract Direccion del contrato de puntos
     */
    constructor(
        IPoolManager _poolManager,
        FootballPoints _pointsContract
    ) Ownable(msg.sender) {
        require(address(_poolManager) != address(0), "PoolManager invalido");
        require(address(_pointsContract) != address(0), "Points invalido");
        
        poolManager = _poolManager;
        pointsContract = _pointsContract;
    }

    // ============ REGISTRO DE POOLS ============

    /**
     * @dev Registra un pool especifico con un equipo
     * @param key La clave del pool
     * @param teamId El ID del equipo (token ID en ERC-1155)
     */
    function registerPool(PoolKey calldata key, uint256 teamId) external onlyOwner {
        require(teamId > 0, "TeamId invalido");
        
        bytes32 poolKeyHash = keccak256(abi.encode(key));
        poolKeyToTeamId[poolKeyHash] = teamId;
        
        emit PoolRegistered(poolKeyHash, teamId);
    }

    // ============ HOOKS INTERFAZ IHooks ============

    function beforeInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96)
        external
        returns (bytes4)
    {
        return IHooks.beforeInitialize.selector;
    }

    function afterInitialize(address sender, PoolKey calldata key, uint160 sqrtPriceX96, int24 tick)
        external
        returns (bytes4)
    {
        return IHooks.afterInitialize.selector;
    }

    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
        return IHooks.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta) {
        return (IHooks.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }

    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
        return IHooks.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta) {
        return (IHooks.afterRemoveLiquidity.selector, BalanceDelta.wrap(0));
    }

    function beforeSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, bytes calldata)
        external
        pure
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        BeforeSwapDelta delta = toBeforeSwapDelta(int128(0), int128(0));
        return (this.beforeSwap.selector, delta, 0);
    }

    /**
     * @dev Hook principal: se ejecuta DESPUES de cada swap
     * 
     * Este es el unico hook que implementamos realmente para esta demostracion.
     * En produccion, todo el acceso a este hook seria controlado por Uniswap v4.
     */
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external returns (bytes4, int128) {
        // Obtener el team ID para este pool
        bytes32 poolKeyHash = keccak256(abi.encode(key));
        uint256 teamId = poolKeyToTeamId[poolKeyHash];

        // Si el pool no esta registrado, no hacemos nada
        if (teamId == 0) {
            return (IHooks.afterSwap.selector, 0);
        }

        // ============ DETECTAR COMPRA vs VENTA ============
        int128 amount0 = delta.amount0();
        int128 amount1 = delta.amount1();

        // Si amount1 > 0, el usuario RECIBE token1 (compra)
        // Si amount1 < 0, el usuario ENVIA token1 (venta)
        bool isBuyingTeamToken = amount1 > 0;

        if (!isBuyingTeamToken) {
            return (IHooks.afterSwap.selector, 0);
        }

        // ============ CALCULAR RECOMPENSA ============
        // El usuario gasto ETH (amount0 es negativo)
        uint256 ethSpent;
        if (amount0 < 0) {
            ethSpent = uint256(int256(-amount0));
        }

        // Calcular 20% del ETH gastado
        uint256 rewardPoints = (ethSpent * REWARD_PERCENTAGE) / 100;

        // ============ MINTEAR PUNTOS ============
        if (rewardPoints > 0) {
            pointsContract.mint(sender, teamId, rewardPoints);
            emit RewardsAwarded(sender, teamId, rewardPoints, ethSpent);
        }

        return (IHooks.afterSwap.selector, 0);
    }

    function beforeDonate(address sender, PoolKey calldata key, uint256 amount0, uint256 amount1, bytes calldata hookData)
        external
        returns (bytes4)
    {
        return IHooks.beforeDonate.selector;
    }

    function afterDonate(address sender, PoolKey calldata key, uint256 amount0, uint256 amount1, bytes calldata hookData)
        external
        returns (bytes4)
    {
        return IHooks.afterDonate.selector;
    }
}
