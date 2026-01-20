-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

# Clean the repo
clean  :; forge clean



# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

# install :; forge install foundry-rs/forge-std@v1.14.0 && forge install smartcontractkit/chainlink-brownie-contracts@1.3.0  && forge install OpenZeppelin/openzeppelin-contracts@v5.5.0

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

coverage :; forge coverage --report lcov

fork-test :; forge test  -vvvv --fork-url $(ALCHEMY_SEPOLIA_RPC_URL)

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1


deploy-sepolia :; forge script script/DeployVault.s.sol:DeployVault --rpc-url $(ALCHEMY_SEPOLIA_RPC_URL) --account MetaMask --sender $(METAMASK_ACCOUNT) --broadcast --password $(LOCAL_PASSWORD) --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv --verify


