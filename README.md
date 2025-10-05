# KipuBank

KipuBank es un contrato inteligente escrito en Solidity que simula un
banco descentralizado con bóvedas personales.\
Permite a los usuarios depositar y retirar ETH bajo ciertas
restricciones de seguridad.

## Características principales

-   Los usuarios pueden depositar ETH en su bóveda personal mediante la
    función `deposit()`.
-   Los retiros están limitados por transacción a un umbral fijo
    (`perTxWithdrawLimit`).
-   Existe un límite global de depósitos (`bankCap`) definido en el
    despliegue del contrato.
-   Los depósitos y retiros emiten eventos (`Deposit`, `Withdraw`).
-   Se utilizan errores personalizados para mayor claridad y seguridad.
-   El contrato implementa buenas prácticas de Solidity: patrón
    checks-effects-interactions, modifiers y visibilidades correctas.
-   Lleva registro del número de depósitos y retiros.

## Estructura del repositorio

    kipu-bank/
    │
    ├── contracts/
    │   └── KipuBank.sol      # Contrato principal
    │
    ├── README.md             # Este archivo

## Instrucciones de despliegue

1.  Clonar el repositorio:

    ``` bash
    git clone https://github.com/tuusuario/kipu-bank.git
    cd kipu-bank
    ```

2.  Abrir el contrato en [Remix](https://remix.ethereum.org/).

3.  Compilar con **Solidity 0.8.20 o superior**.

4.  En la pestaña **Deploy & Run Transactions**, elegir el entorno (ej.
    `Injected Provider - MetaMask` para testnet).

5.  Ingresar los parámetros del constructor al desplegar:

    -   `bankCap`: límite total del banco (en wei).
    -   `perTxWithdrawLimit`: máximo retiro por transacción (en wei).

6.  Presionar **Deploy**.

## Cómo interactuar con el contrato

### Depósitos

-   Usar la función `deposit()`.
-   Antes de llamar a `deposit`, asignar un valor en el campo **VALUE**
    de Remix (ejemplo: `1 ether`).

### Retiros

-   Usar la función `withdraw(uint256 amount)`.
-   Solo se puede retirar hasta el límite por transacción definido en el
    constructor.
-   El retiro transfiere fondos a la dirección del remitente.

### Consultas

-   `getMyBalance()`: devuelve tu balance en la bóveda.
-   `getBalanceOf(address user)`: devuelve el balance de otro usuario.
-   `getTotalBankBalance()`: devuelve el balance total del banco.
-   `getDepositWithdrawCount(address user)`: devuelve la cantidad de
    depósitos y retiros de un usuario.

## Dirección desplegada

Una vez desplegado en una testnet (Goerli / Sepolia), incluye aquí la
dirección del contrato y el link al verificador en el block explorer.

Ejemplo:

    Dirección: 0x1234...abcd
    Block Explorer: https://sepolia.etherscan.io/address/0x1234...abcd#code

## Licencia

Este proyecto es de uso educativo y está bajo la licencia MIT.
