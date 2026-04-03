// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {FootballPoints} from "../src/FootballPoints.sol";
import {PointsHook} from "../src/PointsHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";

/**
 * @title DeploymentScript
 * @dev Script para desplegar en testnet Sepolia
 * 
 * Uso:
 * 
 * 1. LOCAL (anvil):
 *    forge script script/DeploymentScript.s.sol --rpc-url http://localhost:8545 --broadcast -vvv
 * 
 * 2. SEPOLIA TESTNET:
 *    forge script script/DeploymentScript.s.sol --rpc-url sepolia --broadcast -vvv --verify
 * 
 * Variables de entorno necesarias (.env):
 *    SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
 *    PRIVATE_KEY=0x...
 *    ETHERSCAN_API_KEY=...
 */

contract DeploymentScript is Script {
    // Resultado del deployment
    FootballPoints public pointsContract;
    PointsHook public hookContract;

    function run() public {
        // Obtener la private key del .env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Obtener direccion del wallet
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== DEPLOYMENT INICIADO ===");
        console.log("Deployer address:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("");

        // Iniciar broadcast de transacciones
        vm.startBroadcast(deployerPrivateKey);

        // PASO 1: DESPLEGAR FOOTBALL POINTS
        console.log("[1] Desplegando FootballPoints...");
        pointsContract = new FootballPoints();
        console.log("[DONE] FootballPoints deployado en:", address(pointsContract));

        // PASO 2: DESPLEGAR HOOK
        // NOTA: Si estas en testnet sin PoolManager, comenta esta seccion
        
        // Para usar en local o con PoolManager real:
        address poolManagerAddress = _getPoolManagerAddress();
        
        if (poolManagerAddress != address(0)) {
            console.log("[2] Desplegando PointsHook...");
            console.log("    PoolManager:", poolManagerAddress);
            
            IPoolManager poolManager = IPoolManager(poolManagerAddress);
            hookContract = new PointsHook(poolManager, pointsContract);
            console.log("[DONE] PointsHook deployado en:", address(hookContract));

            // PASO 3: AUTORIZAR HOOK
            console.log("[3] Autorizando Hook como minter...");
            pointsContract.addMinter(address(hookContract));
            console.log("[DONE] Hook autorizado como minter");
        } else {
            console.log("[WARNING] PoolManager no encontrado en esta red");
            console.log("    Solo se desplego FootballPoints");
            console.log("    Para desplegar Hook necesitas:");
            console.log("    1. Uniswap v4 PoolManager desplegado");
            console.log("    2. Actualizar _getPoolManagerAddress()");
        }

        vm.stopBroadcast();

        // RESUMEN
        _printSummary(deployer);
    }

    /**
     * @dev Obtiene la direccion del PoolManager segun la red
     */
    function _getPoolManagerAddress() internal view returns (address) {
        uint256 chainId = block.chainid;
        
        if (chainId == 31337) {
            // ANVIL LOCAL - Necesitarias desplegar PoolManager localmente primero
            console.log("[ANVIL] Usando PoolManager local (si existe)");
            return address(0); // TODO: Desplegar PoolManager en anvil
        } 
        else if (chainId == 11155111) {
            // SEPOLIA TESTNET
            // Direccion a actualizar con la direccion real de Uniswap v4 en Sepolia
            console.log("[SEPOLIA] Buscando PoolManager...");
            return address(0); // TODO: Obtener direccion real de Sepolia
        }
        else if (chainId == 1) {
            // MAINNET
            console.log("[MAINNET] PoolManager");
            return address(0); // TODO: Direccion en mainnet
        }
        else {
            console.log("[UNKNOWN CHAIN] ChainID:", chainId);
            return address(0);
        }
    }

    /**
     * @dev Imprime un resumen del deployment
     */
    function _printSummary(address deployer) internal view {
        console.log("");
        console.log("=== DEPLOYMENT COMPLETADO ===");
        console.log("Deployer:", deployer);
        console.log("FootballPoints:", address(pointsContract));
        if (address(hookContract) != address(0)) {
            console.log("PointsHook:", address(hookContract));
        }
        console.log("Chain ID:", block.chainid);
        console.log("Timestamp:", block.timestamp);
        
        console.log("");
        console.log("=== VERIFICAR EN ETHERSCAN ===");
        console.log("Sepolia: https://sepolia.etherscan.io/address/", address(pointsContract));
        
        if (address(hookContract) != address(0)) {
            console.log("         https://sepolia.etherscan.io/address/", address(hookContract));
        }
    }
}

/**
 * @title DeployOnlyPoints
 * @dev Script SIMPLIFICADO que solo despliega FootballPoints
 * Util cuando no tienes PoolManager disponible
 * 
 * Uso:
 *    forge script script/DeploymentScript.s.sol:DeployOnlyPoints --rpc-url sepolia --broadcast -vvv
 */
contract DeployOnlyPoints is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== DEPLOYMENTONLY POINTS ===");
        console.log("Deployer:", deployer);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        FootballPoints points = new FootballPoints();
        
        console.log("[SUCCESS] FootballPoints deployado en:");
        console.log("   ", address(points));

        vm.stopBroadcast();

        console.log("");
        console.log("=== NEXT STEPS ===");
        console.log("1. Copia la direccion:", address(points));
        console.log("2. Verifica en Etherscan");
        console.log("3. Cuando tengas PoolManager, despliega el Hook");
    }
}
