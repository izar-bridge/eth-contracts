# To load the variables in the .env file
source .env


# To deploy and verify our contract
forge script script/DeployMintAllERC20.s.sol:DeployMintAllERC20 --rpc-url $RPC_URL --broadcast --verify -vvvv

