// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title PointsHookTest
 * @dev Tests para el Hook de puntos de Uniswap v4
 */

import {Test} from "forge-std/Test.sol";
import {FootballPoints} from "../src/FootballPoints.sol";
import {PointsHook} from "../src/PointsHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolKey, PoolId} from "v4-core/types/entities/Pool.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {Constants} from "v4-core/libraries/Constants.sol";

contract PointsHookTest is Test {
    // Contratos instanciados
    FootballPoints public pointsContract;
    PointsHook public hook;

    // Direcciones de prueba
    address public user = makeAddr("user");
    address public owner = makeAddr("owner");

    // Parámetros de prueba
    uint256 constant TEAM_BRASIL_ID = 1;
    uint256 constant SWAP_AMOUNT_ETH = 1 ether;

    function setUp() public {
        // Cambiar a la dirección del owner
        vm.startPrank(owner);

        // Desplegamos el contrato de puntos
        pointsContract = new FootballPoints();

        // Desplegamos un PoolManager mock (para prueba simplificada)
        // En un escenario real, usarías el PoolManager de Uniswap v4 en testnet
        // address poolManager = address(0x1234567890123456789012345678901234567890);

        // Para este test simplificado, creamos un mock
        // DeployerHook deployerHook = new DeployerHook();
        
        // Por ahora, saltaremos la parte de PoolManager y enfocarnos en la lógica
        
        vm.stopPrank();
    }

    /**
     * @dev Test 1: Verificar que el contrato de puntos se despliega correctamente
     */
    function test_PointsContractDeployment() public {
        assertNotEq(address(pointsContract), address(0));
    }

    /**
     * @dev Test 2: Verificar que solo minters pueden mintear
     */
    function test_OnlyMinterCanMint() public {
        vm.startPrank(owner);

        // Agregamos al usuario como minter
        pointsContract.addMinter(user);

        // Verificamos que el usuario es minter
        assertTrue(pointsContract.isMinter(user));

        vm.stopPrank();

        // El usuario mintea puntos
        vm.startPrank(user);
        pointsContract.mint(user, TEAM_BRASIL_ID, 100);
        vm.stopPrank();

        // Verificamos que el usuario recibió los puntos
        uint256 balance = pointsContract.balanceOf(user, TEAM_BRASIL_ID);
        assertEq(balance, 100);
    }

    /**
     * @dev Test 3: Intentar mintear sin permisos falla
     */
    function test_UnauthorizedMintFails() public {
        vm.startPrank(user);

        // El usuario intenta mintear sin ser minter
        vm.expectRevert("No tienes permiso de minter");
        pointsContract.mint(user, TEAM_BRASIL_ID, 100);

        vm.stopPrank();
    }

    /**
     * @dev Test 4: Remover minter funciona correctamente
     */
    function test_RemoveMinterWorks() public {
        vm.startPrank(owner);

        // Agregamos minter
        pointsContract.addMinter(user);
        assertTrue(pointsContract.isMinter(user));

        // Removemos minter
        pointsContract.removeMinter(user);
        assertFalse(pointsContract.isMinter(user));

        vm.stopPrank();
    }

    /**
     * @dev Test 5: Multiple users pueden recibir puntos del mismo equipo
     */
    function test_MultipleUsersSameTeam() public {
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        vm.startPrank(owner);
        pointsContract.addMinter(owner);
        pointsContract.mint(user1, TEAM_BRASIL_ID, 50);
        pointsContract.mint(user2, TEAM_BRASIL_ID, 75);
        vm.stopPrank();

        assertEq(pointsContract.balanceOf(user1, TEAM_BRASIL_ID), 50);
        assertEq(pointsContract.balanceOf(user2, TEAM_BRASIL_ID), 75);
    }

    /**
     * @dev Test 6: Verificar eventos de minería
     */
    function test_PointsMintedEventEmitted() public {
        vm.startPrank(owner);
        pointsContract.addMinter(owner);

        // Esperamos el evento PointsMinted
        vm.expectEmit(true, true, false, true);
        emit FootballPoints.PointsMinted(user, TEAM_BRASIL_ID, 100);

        pointsContract.mint(user, TEAM_BRASIL_ID, 100);

        vm.stopPrank();
    }

    /**
     * @dev Test 7: Team IDs diferentes (múltiples equipos)
     */
    function test_MultipleTeams() public {
        uint256 teamArgenina = 2;
        uint256 teamPeru = 3;

        vm.startPrank(owner);
        pointsContract.addMinter(owner);

        pointsContract.mint(user, TEAM_BRASIL_ID, 100);
        pointsContract.mint(user, teamArgenina, 80);
        pointsContract.mint(user, teamPeru, 60);

        vm.stopPrank();

        assertEq(pointsContract.balanceOf(user, TEAM_BRASIL_ID), 100);
        assertEq(pointsContract.balanceOf(user, teamArgenina), 80);
        assertEq(pointsContract.balanceOf(user, teamPeru), 60);
    }

    /**
     * @dev Test 8: No se puede mintear cantidad 0
     */
    function test_CannotMintZeroAmount() public {
        vm.startPrank(owner);
        pointsContract.addMinter(owner);

        vm.expectRevert("Cantidad debe ser > 0");
        pointsContract.mint(user, TEAM_BRASIL_ID, 0);

        vm.stopPrank();
    }

    /**
     * @dev Test 9: No se puede mintear a dirección 0
     */
    function test_CannotMintToZeroAddress() public {
        vm.startPrank(owner);
        pointsContract.addMinter(owner);

        vm.expectRevert("Destinatario inválido");
        pointsContract.mint(address(0), TEAM_BRASIL_ID, 100);

        vm.stopPrank();
    }
}
