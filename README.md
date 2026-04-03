# HYP - Uniswap v4 Hook 🏈⚽

Un sistema de recompensas basado en **Uniswap v4 Hooks** que permite premiar a usuarios que realizan swaps en un pool, ganando puntos de equipo de fútbol (ERC-1155 tokens).

## Proyecto

Este proyecto implementa un Hook personalizado para **Uniswap v4** que:

1. **Detecta swaps** en un pool de liquidez
2. **Premia a compradores** con puntos de equipos de fútbol
3. **Gestiona puntos** como tokens ERC-1155 (uno por equipo)
4. **Registra eventos** de transacciones y recompensas

### Caso de Uso

Imagina un mercado de predicción donde:
- Cada token ERC-1155 representa las "energías" de un equipo de fútbol
- Cada vez que alguien compra tokens USDC/ETH en el pool, el Hook les premia con puntos
- Los puntos se pueden canjear, vender o usar en predicciones deportivas

## Contrato Desplegado ✅

### Sepolia Testnet

**HYP Token (ERC-1155)**
- Dirección: [`0x2B62ac0dbb0e7b96F2c38B6b5aDDF0C8470096F9`](https://sepolia.etherscan.io/address/0x2B62ac0dbb0e7b96F2c38B6b5aDDF0C8470096F9)
- Red: Sepolia (Chain ID: 11155111)
- TX Hash: `0x4b96647aefcbfd9fce19492c24419c4c4616c46b2d422f4423163cba8615a6b1`
- Ver en Etherscan: https://sepolia.etherscan.io/address/0x2B62ac0dbb0e7b96F2c38B6b5aDDF0C8470096F9

## Estructura del Proyecto

### Contratos Inteligentes

```
src/
├── FootballPoints.sol      # Token ERC-1155 de puntos de equipos
└── PointsHook.sol          # Hook de Uniswap v4 que premia swaps
```

#### FootballPoints.sol (ERC-1155)
- Tokenniza puntos de equipos (ID = número de equipo)
- Solo propietario y minsters autorizados pueden crear puntos
- Emite eventos al crear/transferir puntos

#### PointsHook.sol (IHooks)
- Implementa interfaz de Uniswap v4 Hooks
- Hook `afterSwap()` detecta compras y premia 20% de puntos
- Mapea pools a IDs de equipos
- Solo minsters (Hook) pueden crear puntos en el token

### Tests

```
test/
└── PointsHook.t.sol        # Suite de 9 tests
```

**Tests incluidos:**
- ✅ Deployment de contratos
- ✅ Validación de permisos (minter)
- ✅ Múltiples usuarios y equipos
- ✅ Recompensas de puntos
- ✅ Eventos y auditoría
- **Estado: 9/9 tests PASSING**

### Scripts

```
script/
└── DeploymentScript.s.sol   # Script de deployment
```

**Dos opciones de deployment:**
- `DeploymentScript`: Deployment completo (con Hook y PoolManager)
- `DeployOnlyPoints`: Solo FootballPoints (sin PoolManager)

## Instalación y Setup

### Requisitos
- Foundry instalado ([getfoundry.sh](https://getfoundry.sh/))
- Wallet con Sepolia ETH (faucet: https://sepoliafaucet.com/)
- RPC de Sepolia (Infura, Alchemy, etc.)

### Clonar y Configurar

```bash
# Clonar repo
git clone <repo_url>
cd hyp

# Instalar dependencias
forge install

# Configurar .env
cp .env.example .env
# Editar .env y agregar:
# PRIVATE_KEY=0x...
# SEPOLIA_RPC_URL=https://...
# ETHERSCAN_API_KEY=...
```

## Uso

### Compilar

```bash
forge build
```

### Ejecutar Tests

```bash
# Todos los tests
forge test

# Con verbosidad
forge test -vvv

# Test específico
forge test --match testMintingPoints
```

### Desplegar en Sepolia

```bash
# Una vez que tengas .env configurado
forge script script/DeploymentScript.s.sol:DeployOnlyPoints \
  --rpc-url sepolia \
  --broadcast -vvv
```

### Interactuar con el Contrato

```bash
# Ver owner del contrato
cast call 0x2B62ac0dbb0e7b96F2c38B6b5aDDF0C8470096F9 \
  "owner()" \
  --rpc-url sepolia

# Verificar si eres minter
cast call 0x2B62ac0dbb0e7b96F2c38B6b5aDDF0C8470096F9 \
  "isMinter(address)" <tu_address> \
  --rpc-url sepolia

# Obtener balance de puntos (token ID 1 = equipo 1)
cast call 0x2B62ac0dbb0e7b96F2c38B6b5aDDF0C8470096F9 \
  "balanceOf(address,uint256)" <tu_address> 1 \
  --rpc-url sepolia
```

## Documentación Adicional

- **ENTREGA_FINAL.md**: Resumen ejecutivo del proyecto
- **HOOK_EXPLICACION.md**: Explicación técnica detallada del Hook
- **README_HOOK.md**: Guía técnica del Hook
- **GUIA_PASO_A_PASO.sol**: Tutorial de integración paso a paso
- **DEPLOYMENT_PASO_A_PASO.md**: Guía de deployment detallada
- **DEPLOYMENT_GUIA.md**: Referencia completa de deployment

## Próximos Pasos

1. ✅ FootballPoints desplegado en Sepolia
2. ⏳ Integrar con PoolManager de Uniswap v4 en Sepolia
3. ⏳ Desplegar PointsHook completo
4. ⏳ Testear rewards en transacciones reales
5. ⏳ Verificar contratos en Etherscan

## Herramientas Usadas

- **Solidity 0.8.24**
- **Foundry**: Compilación, testing y deployment
- **Uniswap v4 Core**: Interfaces y tipos de hooks
- **OpenZeppelin**: Contratos ERC-1155 y Ownable
- **Sepolia Testnet**: Red de pruebas

## Referencias

- [Foundry Book](https://book.getfoundry.sh/)
- [Uniswap v4 Hooks](https://docs.uniswap.org/contracts/v4/)
- [Sepolia Etherscan](https://sepolia.etherscan.io/)

---

**HYP - Proyecto Final - Defi Ethereum Bolivia 2026**
