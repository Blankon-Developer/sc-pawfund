# Pawfund Smart Contracts

Pawfund is a USDC-based crowdfunding system for animal donations on Base. An operator creates
official campaigns through the factory, donors send USDC to individual campaigns, and each
fundraiser can withdraw funds directly to the wallet configured when the campaign was created.

## Architecture

### PawfundFactory

- Owned by a single operator using OpenZeppelin `Ownable2Step`.
- Only the owner can call
  `createCampaign(address fundraiser, uint256 goalAmount, uint256 endAt)`.
- The factory uses one immutable canonical USDC address for every campaign.
- Official campaigns are discovered through the `CampaignCreated` event; the factory does not
  maintain an on-chain registry.
- Ownership cannot be renounced, but it can be transferred through a two-step process.

### PawfundCampaign

- Stores `fundraiser`, `goalAmount`, `endAt`, and USDC as immutable values.
- `donate(uint256 amount)` accepts USDC until `endAt`.
- `withdraw(uint256 amount)` only sends USDC to the fundraiser.
- The fundraiser can make partial withdrawals at any time, including while the campaign is active.
- `goalAmount` is informational. Donations may exceed the target.
- There are no refunds, protocol fees, pause/cancel controls, or campaign configuration changes.

`goalAmount` and every `amount` parameter use USDC base units:

```text
1 USDC = 1_000_000
```

`endAt` is a Unix timestamp in seconds (UTC). A campaign closes exactly when
`block.timestamp >= endAt`.

## Toolchain and Dependencies

The project uses Solidity `0.8.36`, Foundry, and Soldeer as its only dependency manager.
Dependency versions are locked in `soldeer.lock`:

- `forge-std 1.16.2`
- `@openzeppelin-contracts 5.6.1`

Install dependencies:

```shell
forge soldeer install --config-location foundry
```

Update dependencies after intentionally changing a version in `foundry.toml`:

```shell
forge soldeer update --config-location foundry
```

Do not use `forge install`, git submodules, or npm for this project's Solidity dependencies.

## Build and Test

```shell
forge fmt --check
forge lint
forge build --force --sizes
forge test -vvv
```

## Base Configuration

Copy the environment configuration and set the operator address and API key:

```shell
cp .env.example .env
source .env
```

Supported networks:

| Network | Chain ID | Canonical USDC |
| --- | ---: | --- |
| Base Sepolia | 84532 | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` |
| Base Mainnet | 8453 | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |

The public RPC endpoints in `.env.example` are rate-limited. Use a dedicated provider for
deployments and production applications.

## Factory Deployment

Store the private key securely in the encrypted Foundry keystore:

```shell
cast wallet import pawfund-deployer --interactive
```

Simulate the deployment before broadcasting:

```shell
forge script script/DeployPawfundFactory.s.sol:DeployPawfundFactory \
  --rpc-url base_sepolia \
  --account pawfund-deployer \
  --sender <DEPLOYER_ADDRESS>
```

Deploy and verify on Base Sepolia:

```shell
forge script script/DeployPawfundFactory.s.sol:DeployPawfundFactory \
  --rpc-url base_sepolia \
  --account pawfund-deployer \
  --sender <DEPLOYER_ADDRESS> \
  --broadcast \
  --verify
```

For mainnet, replace `base_sepolia` with `base_mainnet`. The script rejects every other chain and
automatically selects the correct canonical USDC address.

## Creating a Campaign

The factory owner creates a campaign using USDC base units and a UTC timestamp:

```shell
cast send <FACTORY_ADDRESS> \
  "createCampaign(address,uint256,uint256)(address)" \
  <FUNDRAISER_ADDRESS> \
  10000000000 \
  <END_AT_TIMESTAMP> \
  --rpc-url base_sepolia \
  --account pawfund-operator
```

In this example, `10000000000` represents a target of `10,000 USDC`.

## Donations and Withdrawals

A donor must grant the campaign an allowance before donating:

```shell
cast send <USDC_ADDRESS> \
  "approve(address,uint256)(bool)" \
  <CAMPAIGN_ADDRESS> \
  25000000 \
  --rpc-url base_sepolia \
  --account donor

cast send <CAMPAIGN_ADDRESS> \
  "donate(uint256)" \
  25000000 \
  --rpc-url base_sepolia \
  --account donor
```

This example donates `25 USDC`.

The fundraiser withdraws funds directly to the stored fundraiser wallet:

```shell
cast send <CAMPAIGN_ADDRESS> \
  "withdraw(uint256)" \
  10000000 \
  --rpc-url base_sepolia \
  --account fundraiser
```

USDC sent directly to the campaign with `transfer` can still be withdrawn by the fundraiser, but it
is not included in `totalDonated` because it did not pass through the `donate` function.
