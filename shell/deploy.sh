# Load environment variables
source .env

# Deploy using script
forge script script/deploy.s.sol:Deploy --rpc-url $RPC_URL --private-key $PRIVATE_KEY --etherscan-api-key $ETHERSCAN_KEY --verify -vvvv
