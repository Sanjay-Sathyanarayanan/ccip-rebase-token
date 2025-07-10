# 🌀 Rebase Token

A token that grows with time — rewarding you just for holding it.

This project is a simple but powerful rebase token built with Foundry and OpenZeppelin.

You deposit ETH or WETH into a Vault and receive rebase tokens in return. These tokens reflect your share of the Vault and grow over time without you lifting a finger. No claiming, no staking. Just hold, and your balance increases automatically.

---

## ⚙️ How It Works

- When you deposit, your entry time is recorded.
- Your balance increases linearly over time, based on a fixed interest rate set at deposit time.
- When you interact with the token (transfer, withdraw, deposit again), the contract calculates and mints your accrued interest before executing your action.
- Early adopters are rewarded with a higher interest rate — the global rate can only go down, never up.

It’s gas efficient, easy to reason about, and built for passive yield experiments and real-world use cases.


## 🧪 Running Tests

This project uses [Foundry](https://book.getfoundry.sh/) for testing. Here’s how to get started:

```sh
# Clone and enter the repo
git clone https://github.com/Sanjay-Sathyanarayanan/ccip-rebase-token.git

# Install dependencies
forge install

# Run all tests
forge test -vv
```

---

## 📄 Contract Overview

- **RebaseToken.sol**: The main ERC20 contract with rebase logic and interest accrual.
- **Vault.sol**: (If present) Handles deposits and interacts with the RebaseToken.
- **Test Suite**: Comprehensive tests in `test/` directory using Foundry.

---



## 🔒 Security

- Uses OpenZeppelin’s battle-tested libraries for ERC20, Ownable, and AccessControl.
- Only the owner can adjust the interest rate.
- Interest rates are “locked in” per user at the time of their last interaction, preventing manipulation.

---

## 🛠️ Customization

- **Interest Rate**: The owner can update the interest rate for future accruals.
- **Access Control**: Roles can be extended for minting/burning or other admin actions.
- **Precision**: All calculations use a high-precision factor to avoid rounding errors.

---

## 📚 Learn More

- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)

---

## 🤝 Contributing

Pull requests and issues are welcome! Please open an issue to discuss your ideas or report bugs.

---

## 📝 License

This project is licensed under the MIT License.