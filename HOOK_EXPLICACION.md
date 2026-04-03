# Sistema de Hooks de Uniswap v4 - Football Points Market

## 📋 Descripción General

Este proyecto implementa un **Hook de Uniswap v4** que crea un sistema de incentivos para un prediction market de fútbol. Los usuarios que compran tokens de equipos reciben **puntos como recompensa**, simulando apuestas simbólicas.

**Idea Central:**
- Cada pool de Uniswap v4 representa un equipo (ej: ETH ↔ BRASIL_TOKEN)
- Cuando un usuario **compra** el token del equipo, recibe puntos como recompensa
- Los puntos son tokens ERC-1155 que representan participación/apuesta

---

## 🏗️ Arquitectura del Proyecto

```
src/
├── FootballPoints.sol    # Contrato ERC-1155 para los puntos
├── PointsHook.sol        # Hook que ejecuta la lógica de recompensas
test/
└── PointsHook.t.sol      # Tests en Foundry
```

### 1. **FootballPoints.sol** - Contrato de Puntos (ERC-1155)

```solidity
contract FootballPoints is ERC1155, Ownable
```

**Propósito:** Mintea y gestiona tokens ERC-1155 como puntos de recompensa.

**Características:**
- Sistema de roles: solo direcciones autorizadas ("minters") pueden mintear puntos
- Token ID = ID del equipo (1 = Brasil, 2 = Argentina, etc.)
- El Hook es el único minter autorizado

**Funciones principales:**
```solidity
// Agregar/remover permisos de minter
addMinter(address _minter)
removeMinter(address _minter)

// Mintear puntos (solo minters)
mint(address _to, uint256 _teamId, uint256 _amount)
```

---

### 2. **PointsHook.sol** - Hook de Uniswap v4

```solidity
contract PointsHook is BaseHook
```

**Propósito:** Escucha todos los swaps en un pool y asigna recompensas a compradores.

**Cómo funciona:**

#### A. Registro de Pools
Cada pool debe registrarse asociándolo con un equipo:

```solidity
registerPool(PoolKey calldata key, uint256 teamId)
```

- `PoolKey`: datos del pool (tokens, fee, tick spacing, etc.)
- `teamId`: ID del equipo en ERC-1155 (ej: 1 para Brasil)

Después del registro, el hook sabe: "*Si ocurre un swap en este pool, es sobre Brasil*"

---

#### B. Detección de Compra vs Venta

El hook escucha el evento `afterSwap` que ocurre después de cada swap.

**¿Cómo sabe si es compra?**

En cada swap, Uniswap calcula `delta` (cambios en balances):

```solidity
int128 amount0 = delta.amount0();  // Cambio en token0 (ETH)
int128 amount1 = delta.amount1();  // Cambio en token1 (BRASIL_TOKEN)
```

**Lógica:**
- Si `amount1 > 0`: Usuario **RECIBE** token del equipo → Es una **COMPRA** ✅
- Si `amount1 < 0`: Usuario **PAGA** token del equipo → Es una **VENTA** ❌

```solidity
bool isBuyingTeamToken = amount1 > 0;
if (!isBuyingTeamToken) return;  // No hay recompensa en venta
```

---

#### C. Cálculo de Recompensas

El 20% del valor del swap (en ETH) se convierte en puntos:

```solidity
// ETH que gastó el usuario (negativo → lo convertimos a positivo)
uint256 ethSpent = uint256(-amount0);

// Calcular el 20%
uint256 rewardPoints = (ethSpent * 20) / 100;

// Si gastó 1 ETH → recibe 0.2 ETH = 0.2 ETH * 10^18 = 200000000000000000 puntos
```

**Ejemplo conciso:**
```
Swap: 1 ETH → N BRASIL_TOKEN
Recompensa: 1 ETH × 20% = 0.2 ETH = 200,000,000,000,000,000 puntos
Al usuario se le mintea 200*10^15 puntos del equipo Brasil
```

---

#### D. Minería de Puntos

```solidity
pointsContract.mint(sender, teamId, rewardPoints);
```

- `sender`: El usuario que hizo el swap
- `teamId`: ID del equipo (Brasil = 1)
- `rewardPoints`: Cantidad calculada (20% del valor en ETH)

---

## 🔄 Flujo Completo

```
1. Usuario ejecuta un SWAP en el pool ETH ↔ BRASIL
   ↓
2. Uniswap v4 ejecuta la transacción del swap
   ↓
3. Se dispara el HOOK afterSwap
   ↓
4. Hook verifica:
   ├─ ¿Está registrado este pool? 
   ├─ ¿El usuario está COMPRANDO (amount1 > 0)?
   ├─ ¿Cuánto ETH gastó? (-amount0)
   └─ ¿Cuál es el 20% del ETH gastado?
   ↓
5. Hook llama: pointsContract.mint(usuario, TEAM_BRASIL_ID, rewardPoints)
   ↓
6. Usuario recibe los puntos como ERC-1155 token
```

---

## 🧪 Testing en Foundry

El archivo `test/PointsHook.t.sol` incluye tests que validan:

1. ✅ Despliegue correcto del contrato
2. ✅ Solo minters pueden mintear
3. ✅ No se puede mintear sin permisos
4. ✅ Se pueden remover minters
5. ✅ Múltiples usuarios pueden recibir puntos
6. ✅ Los eventos se emiten correctamente
7. ✅ Múltiples equipos trabajan independientemente
8. ✅ No se puede mintear cantidad 0
9. ✅ No se puede mintear a dirección 0

**Ejecutar tests:**
```bash
forge test
```

---

## 🔒 Seguridad

### Medidas Implementadas

1. **Validaciones de entrada:**
   - Cantidad > 0
   - Dirección destino ≠ 0
   - TeamId válido (aunque es simple)

2. **Control de acceso:**
   - Solo el owner puede agregar/remover minters
   - Solo minters autorizados pueden mintear
   - El hook es el minter principal

3. **Lógica segura:**
   - Revisar si el pool está registrado antes de actuar
   - Solo procesar compras (no ventas)
   - Usar cálculos matemáticos seguros (sin problemas de overflow porque usamos `/`)

### Qué falta (para producción):
- Checks de reentrancia más robustos
- Pricing oracle para más precisión
- Limites de recompensa máxima por transacción
- Pausable pattern
- Eventos más detallados para auditoría

---

## 📊 Ejemplos de Uso

### Escenario 1: Usuario compra Brasil
```
Pool: ETH ↔ BRASIL (Team ID = 1)

Swap:
  Input: 2 ETH
  Output: 1000 BRASIL tokens

Hook calcula:
  - ¿Está comprando? amount1 = +1000 ✅
  - ETH gastado: 2 ETH
  - Recompensa: 2 × 20% = 0.4 ETH = 400,000,000,000,000,000 puntos

Resultado:
  Usuario recibe +400*10^15 puntos de Brasil
```

### Escenario 2: Usuario vende Brasil
```
Pool: ETH ↔ BRASIL (Team ID = 1)

Swap:
  Input: 1000 BRASIL tokens
  Output: 1.5 ETH

Hook calcula:
  - ¿Está comprando? amount1 = -1000 ❌
  - No se mintean puntos (es una venta)

Resultado:
  Usuario recibe 0 puntos
```

### Escenario 3: Múltiples equipos
```
Pool1: ETH ↔ BRASIL (Team ID = 1)
Pool2: ETH ↔ ARGENTINA (Team ID = 2)
Pool3: ETH ↔ PERU (Team ID = 3)

Usuario hace 3 swaps:
  1. Compra 1 ETH en BRASIL → +200*10^15 puntos Brasil
  2. Compra 0.5 ETH en ARGENTINA → +100*10^15 puntos Argentina
  3. Vende en PERU → +0 puntos

Saldo final del usuario:
  - BRASIL: 200*10^15
  - ARGENTINA: 100*10^15
  - PERU: 0
```

---

## 🚀 Cómo Comenzar

### 1. Compilar
```bash
forge build
```

### 2. Ejecutar Tests
```bash
forge test
```

### 3. Para usar en testnet (ejemplo)

```solidity
// 1. Desplegar FootballPoints
FootballPoints points = new FootballPoints();

// 2. Desplegar Hook con PoolManager y puntos
PointsHook hook = new PointsHook(poolManager, points);

// 3. Autorizar el hook como minter
points.addMinter(address(hook));

// 4. Registrar pools con equipos
hook.registerPool(pooljKey_Brasil, 1);
hook.registerPool(poolKey_Argentina, 2);

// 5. ¡Listo! Usuarios que hagan swaps recibirán puntos automáticamente
```

---

## 📝 Parámetros Configurables

Si quieres modificar el sistema:

```solidity
// En PointsHook.sol
uint256 public constant REWARD_PERCENTAGE = 20;  // Cambiar a 10, 25, etc.

// En FootballPoints.sol
// Puedes extender addMinter/removeMinter con más lógica
```

---

## 🎯 Casos de Uso Reales

1. **Prediction Markets:** Usuarios "apuestan" comprando tokens, ganan puntos
2. **Gamification:** Los puntos se pueden canjear por NFTs, merchandise, etc.
3. **Loyalty Program:** Recompensar a usuarios por participar
4. **Community Building:** Trackear participación mediante puntos

---

## ✨ Características del Código

- **Bien comentado:** Cada sección explica qué hace
- **Modular:** Separado en Hook y Puntos
- **Testeado:** Suite de tests completa en Foundry
- **Seguro:** Validaciones y control de acceso
- **Simple:** Fácil de entender y extender

---

## 🤔 FAQ

**P: ¿Por qué 20%?**
A: Es un parámetro arbitrario. Representa el "incentivo de compra". Puedes cambiarla.

**P: ¿Qué pasa con los decimales?**
A: ETH y puntos usan 18 decimales (estándar EVM). Las matemáticas maneja esto automáticamente.

**P: ¿Puedo tener más de un hook por pool?**
A: No. Un pool una vez inicializado solo puede tener un hook. Pero un hook puede servir múltiples pools.

**P: ¿Es resistant a reentrancy?**
A: Parcialmente. Checks-Effects-Interactions no es tan crítico aquí porque solo minteamos puntos (no transferimos ETH).

---

## 📚 Recursos

- [Uniswap v4 Hooks Documentation](https://docs.uniswap.org/contracts/v4/guides/hooks)
- [ERC-1155 Standard](https://eips.ethereum.org/EIPS/eip-1155)
- [Foundry Book](https://book.getfoundry.sh/)

---

**Creado con ❤️ para aprender sistemas de hooks en Uniswap v4**
