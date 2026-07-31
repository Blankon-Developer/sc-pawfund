# Repository Guidelines

## Project Structure & Module Organization

- `src/` contains the production contracts: `PawfundFactory.sol` deploys operator-approved campaigns, while `PawfundCampaign.sol` receives and releases USDC.
- `test/` contains Forge tests. Shared test tokens belong in `test/mocks/`.
- `script/` contains deployment scripts, currently `DeployPawfundFactory.s.sol`.
- `foundry.toml` defines Solidity `0.8.36`, Osaka EVM settings, Base RPC aliases, and Soldeer dependencies.
- Generated `dependencies/`, `cache/`, `out/`, and local `.env` files must remain untracked.

## Build, Test, and Development Commands

Install locked dependencies with Soldeer:

```sh
forge soldeer install --config-location foundry
```

Do not use `forge install`, npm, or git submodules for Solidity dependencies. Run the same checks used by CI:

```sh
forge fmt --check
forge lint
forge build --force --sizes
forge test -vvv
```

Use `forge test --match-contract PawfundCampaignTest` or `--match-test test_Donate` for focused runs. Copy `.env.example` to `.env` before simulating deployment; follow the commands in `README.md`.

## Coding Style & Naming Conventions

Use four-space indentation and let `forge fmt` determine Solidity formatting. Pin the pragma to the configured compiler version. Name contracts and custom errors in `PascalCase`, functions and variables in `camelCase`, and constants in `UPPER_SNAKE_CASE`. Prefer custom errors, indexed event fields, immutable configuration, OpenZeppelin utilities, and NatSpec for public behavior. Keep checks-effects-interactions ordering and protect token-moving entry points against reentrancy.

## Testing Guidelines

Tests use Forge and `forge-std`. Test files end in `.t.sol`, suites end in `Test`, setup belongs in `setUp()`, and cases use `test_...`, `test_RevertWhen_...`, or `testFuzz_...`. Cover success paths, authorization, zero values, time boundaries, events, accounting, and token-transfer failures. Every behavior change should include a regression test; run the full suite before submitting.

## Commit & Pull Request Guidelines

Follow the existing Conventional Commit style, such as `feat: add ...`, `test: cover ...`, `docs: document ...`, and `chore: migrate ...`. Keep commits small and independently understandable. Pull requests should explain the contract behavior and security impact, link relevant issues, list verification commands, and note any deployment or environment changes. Screenshots are unnecessary unless documentation gains visual output.

## Security & Configuration

Never commit private keys or `.env`. Use an encrypted Foundry keystore for broadcasts. Validate changes against both Base Sepolia and Base mainnet configuration, but test on Sepolia before any mainnet deployment. Treat canonical USDC addresses, ownership rules, withdrawal authorization, and campaign deadlines as security-sensitive.
