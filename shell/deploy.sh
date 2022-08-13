# Load environment variables
source .env

# Deploy using script
forge script script/Deploy.sol:DeployGovernance --rpc-url $RPC_URL --private-key $PRIVATE_KEY --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv
