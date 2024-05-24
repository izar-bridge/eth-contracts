# To load the variables in the .env file
source .env

# To deploy and verify our contract
forge script script/DeployAll.s.sol:DeployAll --rpc-url $RPC_URL --broadcast --verify -vvvv
