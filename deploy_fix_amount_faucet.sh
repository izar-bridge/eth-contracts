# To load the variables in the .env file
source .env


# To deploy and verify our contract
forge script script/DeployFixedAmountFaucet.s.sol:DeployFixedAmountFaucet --rpc-url $RPC_URL --broadcast --verify -vvvv

