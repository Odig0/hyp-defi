# Uniswap v4 Football Points Hook

Sistema de incentivos de prediction market para fútbol usando un Hook de Uniswap v4.

## 🎯 Concepto

Este proyecto implementa un **hook personalizado** que otorga recompensas (puntos) a los usuarios cuando compran tokens de equipos de fútbol en Uniswap v4.

**Estructura:**
- **Pool**: Representa un equipo (ej: ETH ↔ BRASIL_TOKEN)
- **Compra**: Usuario intercambia ETH por BRASIL_TOKEN
- **Recompensa**: Hook detecta la compra y mintea puntos (20% del valor en ETH)
- **Puntos**: Tokens ERC-1155 que representan participación simbólica

---

## 📁 Archivos Clave

| Archivo | Descripción |
|---------|-------------|
| `src/FootballPoints.sol` | Contrato ERC-1155 para puntos de recompensa |
| `src/PointsHook.sol` | Hook de Uniswap v4 que ejecuta la lógica |
| `test/PointsHook.t.sol` | Suite de tests en Foundry |
| `HOOK_EXPLICACION.md` | Explicación detallada del funcionamiento |

---

## 🚀 Inicio Rápido

### 1. Compilar
```bash
forge build
```

### 2. Tests
```bash
forge test
```

Expected output:
```
✅ 9 tests passed
```

---

## 💻 Cómo Funciona

### 1. Despliegue
```solidity
FootballPoints points = new FootballPoints();
PointsHook hook = new PointsHook(poolManager, points);
points.addMinter(address(hook));
```

### 2. Registro de Pool
```solidity
PoolKey memory brasilPool = PoolKey({...});
hook.registerPool(brasilPool, 1);  // Team ID: 1 = Brasil
```

### 3. Usuario Hace Swap
```
Usuario: "Quiero 100 BRASIL tokens"
entrada: 1 ETH
salida: 100 BRASIL tokens
```

### 4. Hook se Activa
```
Hook detects: usuario recibió BRASIL (compra)
Calcula: 1 ETH × 20% = 0.2 ETH
Mintea: 200,000,000,000,000,000 puntos Brasil
Resultado: usuario tiene 200*10^15 "Brasil Points"
```

---

## 📊 Lógica de Compra vs Venta

### COMPRA (Recompensado)
```
User: envía ETH → recibe BRASIL_TOKEN
Hook: amount1 > 0 ✅ → Mintea puntos
```

### VENTA (Sin Recompensa)
```
User: envía BRASIL_TOKEN → recibe ETH
Hook: amount1 < 0 ❌ → No mintea puntos
```

---

## 🧪 Tests

Todos los tests están en `test/PointsHook.t.sol`:

- ✅ Despliegue correcto
- ✅ Control de permisos de minter
- ✅ Solo minters pueden mintear
- ✅ Remover minters funciona
- ✅ Múltiples usuarios, mismo equipo
- ✅ Eventos se emiten correctamente
- ✅ Múltiples equipos independientes
- ✅ Validaciones básicas

**Ejecutar:**
```bash
forge test -v
```

---

## ⚙️ Configuración

### Cambiar Porcentaje de Recompensa

En `src/PointsHook.sol`:

```solidity
uint256 public constant REWARD_PERCENTAGE = 20;  // Cambiar a 10, 25, etc.
```

### Cambiar Minter

En `src/FootballPoints.sol`:

```solidity
// Solo owner puede hacer esto
points.addMinter(address(nuevoHook));
points.removeMinter(address(hookAntiguo));
```

---

## 🔒 Seguridad

### Implementado
- ✅ Validaciones de entrada
- ✅ Control de acceso (solo owner y minters)
- ✅ Lógica correcta de detección de compra/venta

### Recomendaciones Producción
- [ ] Auditoría de seguridad profesional
- [ ] Testing adicional con diferentes pools
- [ ] Pausable pattern
- [ ] Limites de recompensa máxima
- [ ] Oráculos de precio más robustos

---

## 📝 Ejemplo Completo

```solidity
// 1. DESPLEGAR
FootballPoints points = new FootballPoints();
PointsHook hook = new PointsHook(poolManager, points);

// 2. AUTORIZAR
points.addMinter(address(hook));

// 3. REGISTRAR POOLS
hook.registerPool(brasilPool, 1);  // Brasil
hook.registerPool(argentinaPool, 2);  // Argentina

// 4. USUARIO COMPRA
// Alice intercambia 1 ETH por BRASIL tokens
// Hook: detecta compra → mintea 200*10^15 puntos Brasil

// 5. AUDITAR
uint256 puntosAlice = points.balanceOf(alice, 1);  
// puntosAlice = 200000000000000000
```

---

## 📚 Recursos Adicionales

- [HOOK_EXPLICACION.md](./HOOK_EXPLICACION.md) - Explicación detallada paso a paso
- [Uniswap v4 Docs](https://docs.uniswap.org/contracts/v4/guides/hooks)
- [ERC-1155 Standard](https://eips.ethereum.org/EIPS/eip-1155)
- [Foundry Book](https://book.getfoundry.sh/)

---

## 🎓 Propósito Educativo

Este proyecto está diseñado para aprender:
- ✅ Cómo funcionan los hooks de Uniswap v4
- ✅ Integración de contratos ERC-1155
- ✅ Testing en Foundry
- ✅ Detección de eventos en blockchain
- ✅ Patrones de reward/incentivización

---

## ❓ FAQ

**P: ¿Por qué 20%?**
A: Es configurable. El 20% es un ejemplo arbitrario.

**P: ¿Qué pasa si el pool no está registrado?**
A: El hook simplemente no hace nada (no mintea puntos).

**P: ¿Puedo tener múltiples hooks?**
A: Un pool solo puede tener un hook. Pero un hook puede servir múltiples pools.

**P: ¿Los puntos se queman al vender?**
A: No. Los puntos son permanentes, no se queman.

---

**Creado con ❤️ para aprender Uniswap v4 Hooks**
