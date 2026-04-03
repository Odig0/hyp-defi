// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title DeploymentExample
 * @dev Ejemplo de cómo desplegar e integrar el sistema de hooks
 * 
 * Este archivo muestra:
 * 1. Cómo desplegar los contratos
 * 2. Cómo registrar pools
 * 3. Cómo el sistema funciona end-to-end
 */

import {FootballPoints} from "./FootballPoints.sol";
import {PointsHook} from "./PointsHook.sol";

/**
 * ============ PASO 1: DESPLIEGUE ============
 * 
 * En Foundry o en una blockchain:
 * 
 *   // Suponemos que ya tenemos un PoolManager de Uniswap v4
 *   IPoolManager poolManager = IPoolManager(0x...);
 *   
 *   // Paso 1a: Desplegar contrato de puntos
 *   FootballPoints points = new FootballPoints();
 *   
 *   // Paso 1b: Desplegar el hook
 *   PointsHook hook = new PointsHook(poolManager, points);
 *   
 *   // Paso 1c: Autorizar el hook para mintear puntos
 *   points.addMinter(address(hook));
 * 
 * ============ RESULTADO ============
 * - FootballPoints está desplegado
 * - PointsHook está desplegado
 * - Hook tiene permiso de mintear
 * - Listos para registrar pools
 */


/**
 * ============ PASO 2: REGISTRAR POOLS ============
 * 
 * Ahora debemos decirle al hook qué pool = qué equipo
 * 
 *   // Necesitamos la PoolKey del pool ETH <> BRASIL
 *   // (Asumimos que ya existe en Uniswap v4)
 *   
 *   PoolKey memory brasilPool = PoolKey({
 *       currency0: Currency.wrap(address(WETH)),
 *       currency1: Currency.wrap(address(BRASIL_TOKEN)),
 *       fee: 500,  // 0.05%
 *       tickSpacing: 10,
 *       hooks: IHooksContract(address(hook))
 *   });
 *   
 *   // Registramos: Este pool es del Team 1 (Brasil)
 *   hook.registerPool(brasilPool, 1);
 *   
 *   // Igual para Argentina
 *   PoolKey memory argentinaPool = PoolKey({
 *       currency0: Currency.wrap(address(WETH)),
 *       currency1: Currency.wrap(address(ARGENTINA_TOKEN)),
 *       fee: 500,
 *       tickSpacing: 10,
 *       hooks: IHooksContract(address(hook))
 *   });
 *   
 *   hook.registerPool(argentinaPool, 2);
 * 
 * ============ RESULTADO ============
 * - Pool ETH <> BRASIL está vinculado a Team ID = 1
 * - Pool ETH <> ARGENTINA está vinculado a Team ID = 2
 * - El hook sabe qué team ID tiene cada pool
 */


/**
 * ============ PASO 3: USUARIOS HACEN SWAPS ============
 * 
 * Ahora los usuarios normalmente usan Uniswap:
 * 
 *   // Usuario Alice quiere comprar Brasil
 *   // Envía transacción a PoolManager.swap()
 *   
 *   IPoolManager.SwapParams memory swapParams = IPoolManager.SwapParams({
 *       poolKey: brasilPool,
 *       amountSpecified: -1 ether,  // -1 negative = "compra exactamente esto de ETH"
 *       sqrtPriceLimitX96: 0
 *   });
 *   
 *   BalanceDelta delta = poolManager.swap(brasilPool, swapParams, "");
 *   
 * ============ QUÉ OCURRE EN LA BLOCKCHAIN ============
 * 
 * 1. Alice envía 1 ETH al PoolManager
 * 2. PoolManager intercambia: 1 ETH → ~10,000 BRASIL tokens
 * 3. Alice recibe los tokens
 * 4. /// <-- AQUÍ SE DISPARA EL HOOK afterSwap
 * 5. Hook verifica: 
 *    - ¿La transacción es en el pool Brasil? SÍ
 *    - ¿amount1 > 0 (Alice RECIBIÓ BRASIL)? SÍ
 *    - ETH gastado: 1 ETH
 *    - 20% de 1 ETH = 0.2 ETH = 200,000,000,000,000,000 wei
 * 6. Hook llama: points.mint(alice, 1, 200000000000000000)
 * 7. Alice ahora tiene 200*10^15 "Brazil Points" 
 * 8. La transacción se completa exitosamente
 * 
 * ============ RESULTADO ============
 * - Alice tiene 10,000 BRASIL tokens
 * - Alice tiene 200*10^15 Brazil Points (token ID 1 en ERC-1155)
 * - Su balance en FootballPoints.balanceOf(alice, 1) = 200*10^15
 */


/**
 * ============ PASO 4: VENTA (SIN RECOMPENSA) ============
 * 
 * Si Alice ahora vende sus Brasil:
 * 
 *   IPoolManager.SwapParams memory swapParams = IPoolManager.SwapParams({
 *       poolKey: brasilPool,
 *       amountSpecified: 10000e18,  // +positive = "vende exactamente esto"
 *       sqrtPriceLimitX96: 0
 *   });
 *   
 *   BalanceDelta delta = poolManager.swap(brasilPool, swapParams, "");
 * 
 * ============ QUÉ OCURRE ============
 * 
 * 1. Alice envía 10,000 BRASIL tokens
 * 2. PoolManager intercambia: 10,000 BRASIL → ~0.95 ETH
 * 3. Alice recibe los ETH
 * 4. /// <-- AQUÍ SE DISPARA EL HOOK afterSwap
 * 5. Hook verifica:
 *    - ¿La transacción es en el pool Brasil? SÍ
 *    - ¿amount1 > 0? NO, amount1 < 0 (VENDIÓ)
 *    - isBuyingTeamToken = false
 *    - Hook RETORNA sin hacer nada
 * 6. Alice NO recibe puntos adicionales
 * 
 * ============ RESULTADO ============
 * - Alice tiene 0 BRASIL tokens
 * - Alice tiene 200*10^15 Brazil Points (sus puntos anteriores)
 * - Su saldo de ETH aumentó ~0.95 ETH
 * - Los puntos son permanentes (no se queman al vender)
 */


/**
 * ============ RESUMEN DEL FLUJO ============
 * 
 * DESPLIEGUE
 *   FootballPoints points = new FootballPoints()
 *   PointsHook hook = new PointsHook(poolManager, points)
 *   points.addMinter(address(hook))
 * 
 * CONFIGURACIÓN
 *   hook.registerPool(brasilPool, 1)
 *   hook.registerPool(argentinaPool, 2)
 *   
 * OPERACIÓN NORMAL
 *   Usuario compra BRASIL → Hook detecta y mintea puntos
 *   Usuario vende BRASIL → Hook no hace nada
 *   Usuario compra ARGENTINA → Hook mintea puntos de Argentina
 *   
 * AUDITORÍA
 *   points.balanceOf(alice, 1) → Puntos Brasil de Alice
 *   points.balanceOf(alice, 2) → Puntos Argentina de Alice
 *   points.balanceOf(alice, 3) → Puntos Perú de Alice
 */
