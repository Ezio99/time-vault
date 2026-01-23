# Time Vault Protocol

**Time Vault** is a decentralized vesting and escrow protocol built on Ethereum. It enables users to securely lock assets for a predetermined duration, utilizing immutable smart contract logic to enforce time-based release schedules.

Designed with a **Depositor-Isolated Architecture**, the protocol facilitates secure, trust-minimized fund management for self-custody, inheritance planning, and third-party vesting without the risk of storage collision or griefing attacks.

Sample contract deployed on Sepolia at - 0x38B1E30Da393ac75217D746714c5fbc256282185

---

## 📖 Table of Contents

- [Time Vault Protocol](#time-vault-protocol)
  - [📖 Table of Contents](#-table-of-contents)
  - [🔍 Overview](#-overview)
  - [✨ Key Features](#-key-features)
  - [🏗 Architecture](#-architecture)
    - [Storage Layout](#storage-layout)
    - [Core Logic](#core-logic)
  - [✅ Prerequisites](#-prerequisites)
  - [⚙️ Installation](#️-installation)
  - [🚀 Usage](#-usage)
    - [Testing](#testing)
    - [Coverage Analysis](#coverage-analysis)
    - [Code Formatting](#code-formatting)
  - [🌍 Deployment](#-deployment)
    - [Configuration](#configuration)
    - [Deploy \& Verify](#deploy--verify)
  - [🤝 Contributing](#-contributing)
  - [📄 License](#-license)

---

## 🔍 Overview

Time Vault addresses the need for secure, time-delayed asset transfers. Unlike simple time-lock contracts, Time Vault utilizes a **unique Locker ID strategy** to allow a **Many-to-Many** relationship between Depositors, Beneficiaries, and Assets.

This ensures that multiple parties can fund a single beneficiary's address independently, using different tokens (ETH, USDC, etc.), with distinct unlock schedules and balance tracking.

The protocol integrates **Chainlink Price Feeds** to enforce economic thresholds (minimum USD value) for ETH deposits and employs the **Checks-Effects-Interactions** pattern to mitigate reentrancy risks.

---

## ✨ Key Features

* **Universal Asset Support:** Supports both native **ETH** and any **ERC-20** token (USDC, LINK, WETH, etc.).
* **Locker ID Pattern:** Utilizes a hashing strategy (`keccak256(token, depositor, beneficiary)`) to strictly isolate every deposit relationship.
* **Flexible Vesting:** Supports both self-custody locking (saving) and third-party vesting (trust funds/payments).
* **Griefing Protection:** Strict access controls ensure that only the original depositor can modify a locker's parameters.
* **Economic Security:** Enforces a minimum deposit value (pegged to USD via Chainlink Oracles) for ETH deposits to prevent dust attacks.
* **Gas Optimized:** Uses a flat mapping structure and strictly typed interfaces to minimize storage costs.

---

## 🏗 Architecture

### Storage Layout
The core data structure uses a flat mapping where the key is a unique hash derived from the token, depositor, and beneficiary.

```solidity
struct Locker {
    uint256 balance;      
    uint256 unlockTime;   // Unix timestamp for release
}

// Locker ID Pattern: Hash(Token, Depositor, Beneficiary) -> Locker
mapping(bytes32 lockerId => Locker) private sLockers;

```

### Core Logic

* **`depositEth`**: Locks native ETH. Enforces a minimum USD value (via Chainlink) to prevent dust attacks.
* **`depositToken`**: Locks any ERC-20 token. Requires the user to `approve` the Vault contract first.
* **`withdraw`**: Allows the *beneficiary* to claim funds only after the `unlockTime` has elapsed.
* *Inputs:* `(tokenAddress, depositorAddress)`.
* *Note:* Use `address(0)` as the token address to withdraw ETH.



---

## ✅ Prerequisites

Ensure you have the following installed on your local development environment:

* **[Foundry](https://book.getfoundry.sh/)** (Forge, Cast, Anvil)
* **[Git](https://git-scm.com/)**
* **Make** (standard build tool)

---

## ⚙️ Installation

1. **Clone the repository:**

```bash
git clone [https://github.com/Ezio99/time-vault.git](https://github.com/Ezio99/time-vault.git)
cd time-vault

```

2. **Install Dependencies:**
Initialize submodules and install required libraries (OpenZeppelin, Chainlink, Forge Std).

```bash
make install

```

3. **Build Project:**
Compile the contracts to ensure everything is set up correctly.

```bash
make build

```

---

## 🚀 Usage

This project utilizes a `makefile` to streamline common development workflows.

### Testing

Run the comprehensive test suite, including Unit, Fuzz, and Integration tests.

```bash
make test

```

### Coverage Analysis

Generate a detailed line-by-line coverage report.

```bash
make coverage

```

*Note: Requires `lcov` installed locally for HTML report generation.*

### Code Formatting

Ensure solidity code complies with the project's style guide.

```bash
make format

```

---

## 🌍 Deployment

The project is configured for deployment to the **Sepolia Testnet**.

### Configuration

Create a `.env` file in the project root with the following variables:

```env
ALCHEMY_SEPOLIA_RPC_URL=[https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY](https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY)
METAMASK_ACCOUNT=your_cast_wallet_account_name
ETHERSCAN_API_KEY=your_etherscan_api_key

```

### Deploy & Verify

Run the deployment script, which will broadcast the transaction and automatically verify the contract source code on Etherscan.

```bash
make deploy-sepolia

```

---

## 🤝 Contributing

Contributions are welcome! Please follow standard open-source guidelines:

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/NewFeature`).
3. Commit your changes (`git commit -m 'feat: Add NewFeature'`).
4. Push to the branch (`git push origin feature/NewFeature`).
5. Open a Pull Request.

---

## 📄 License

This project is licensed under the **MIT License**.
