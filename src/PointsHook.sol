// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title PointsHook
 * @dev Hook de Uniswap v4 que recompensa a los usuarios que compran tokens de equipos
 * 
 * Funciona así:
 * 1. Escucha todos los swaps del pool
 * 2. Detecta si el usuario está COMPRANDO el token del equipo (token1)
 * 3. Calcula el 20% del valor del swap en ETH
 * 4. Mintea puntos equivalentes como recompensa
 */

import {BaseHook} from "v4-core/BaseHook.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey, PoolId, Pool} from "v4-core/types/entities/Pool.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {FootballPoints} from "./FootballPoints.sol";

contract PointsHook is BaseHook {
    // Referencia al contrato de puntos
    FootballPoints public pointsContract;

    // Mapeo: key de pool ID => ID del equipo en ERC-1155
    // Esto te permite asociar cada pool con un equipo específico
    mapping(PoolId => uint256) public poolToTeamId;

    // Porcentaje de recompensa: 20% = 20 (pensado como 20/100)
    uint256 public constant REWARD_PERCENTAGE = 20;

    // Eventos para auditoría
    event PoolRegistered(PoolId indexed poolId, uint256 teamId);
    event RewardsAwarded(address indexed user, uint256 indexed teamId, uint256 points);

    /**
     * @dev Constructor del Hook
     * @param _poolManager Dirección del PoolManager de Uniswap v4
     * @param _pointsContract Dirección del contrato de puntos
     */
    constructor(
        IPoolManager _poolManager,
        FootballPoints _pointsContract
    ) BaseHook(_poolManager) {
        require(address(_pointsContract) != address(0), "Puntos invalido");
        pointsContract = _pointsContract;
    }

    // ============ HOOKS REQUERIDAS ============

    /**
     * @dev Retorna qué hooks implementamos (solo afterSwap)
     */
    function getHooksCalls() public pure override returns (Hooks.Calls memory) {
        return Hooks.Calls({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            noOpSwap: false,
            noOpPositionModify: false
        });
    }

    // ============ REGISTRO DE POOLS ============

    /**
     * @dev Registra un pool específico con un equipo
     * Solo el owner puede hacerlo
     * @param key La clave del pool
     * @param teamId El ID del equipo (token ID en ERC-1155)
     */
    function registerPool(PoolKey calldata key, uint256 teamId) external {
        PoolId poolId = key.toId();
        poolToTeamId[poolId] = teamId;
        emit PoolRegistered(poolId, teamId);
    }

    // ============ HOOK PRINCIPAL: afterSwap ============

    /**
     * @dev Se ejecuta DESPUÉS de cualquier swap en el pool
     * 
     * Parámetros explicados:
     * - sender: quién ejecutó el swap (usuario)
     * - key: datos del pool (token0, token1, fee, etc)
     * - params: parámetros del swap
     * - delta: cambios en balances (positivo = recibe, negativo = paga)
     */
    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external override returns (bytes4) {
        // El hookData puede contener parámetros adicionales si lo necesitas
        // Por ahora no lo usamos

        PoolId poolId = key.toId();
        uint256 teamId = poolToTeamId[poolId];

        // Si el pool no está registrado, no hacemos nada
        if (teamId == 0) {
            return BaseHook.afterSwap.selector;
        }

        // ============ DETECTAR COMPRA vs VENTA ============
        // En Uniswap:
        // - delta0 > 0: usuario RECIBE token0 (vende token1)
        // - delta0 < 0: usuario PAGA token0 (compra token1)
        // - delta1 > 0: usuario RECIBE token1 (vende token0)
        // - delta1 < 0: usuario PAGA token1 (compra token0)

        // Si amountSpecified > 0 en params, el usuario está pagando (swap exacto de entrada)
        // Si amountSpecified < 0, el usuario está pidiendo exacto de salida (swap exacto de salida)

        int128 amount0 = delta.amount0();
        int128 amount1 = delta.amount1();

        // Determinamos si es una COMPRA del token1 (token del equipo)
        // COMPRA: usuario recibe token1 positivo (delta1 > 0)
        bool isBuyingTeamToken = amount1 > 0;

        // Si es una venta, no otorgamos recompensas
        if (!isBuyingTeamToken) {
            return BaseHook.afterSwap.selector;
        }

        // ============ CALCULAR RECOMPENSA ============
        // Usamos el valor en token0 (ETH) que se gastó
        // exactAmount0 es lo que el usuario pagó en token0 (será negativo)
        uint256 ethSpent = uint256(-amount0);

        // Calcular el 20% del ETH gastado
        uint256 rewardPoints = (ethSpent * REWARD_PERCENTAGE) / 100;

        // ============ MINTEAR PUNTOS ============
        // Usamos la referencia al contrato de puntos para mintear
        // Enviamos al sender (quien hizo el swap)
        pointsContract.mint(sender, teamId, rewardPoints);

        emit RewardsAwarded(sender, teamId, rewardPoints);

        // Retornamos el selector para confirmar que procesamos el hook correctamente
        return BaseHook.afterSwap.selector;
    }
}
