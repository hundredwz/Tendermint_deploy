# Tendermint_deploy
This is an automated deployment script form Tendermint.

The official methods for testing Tendermint is unfriendly to the new and impossible for chinese users.

So i write this script to deploy a test network.

If you need more functions, change it and use it as your style.

## usage
```
docker pull hundred666/tendermint:0.27.3
git clone https://github.com/hundredwz/Tendermint_deploy.git
cd Tendermint_deploy-master
./network.sh -m up
```

Besides, this image is built from dockerfile form docker folder. In other words, you can build your own image and start the network.
