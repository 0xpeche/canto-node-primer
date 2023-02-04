#!/usr/bin/env bash

set -e

MONIKER="YOUR_MONIKER_HERE"
ENABLE_CORS="true"

ENABLE_REST_API="true"
REST_API_PORT="1317"

PUBLIC_RPC="true"
RPC_PORT="26657"

# === Don't change anything below this line ===
# Checks to see if you've already installed Canto
#
[ -e /$HOME/Canto ] && rm -rf /$HOME/Canto
[ -e /$HOME/.cantod/config/genesis.json ] && rm -rf /$HOME/.cantod/config/genesis.json

# Updates system and installs dependencies
sudo apt-get -y update && sudo apt-get -y upgrade
sudo apt-get install -y git gcc make jq
curl -LO https://go.dev/dl/go1.20.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.20.linux-amd64.tar.gz
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOPATH/bin:$GOROOT/bin:$PATH
source ~/.bashrc

cd /$HOME/
git clone https://github.com/Canto-Network/Canto.git
cd Canto
git checkout v5.0.0

# Installs and builds Canto daemon program
cd $HOME/Canto/cmd/cantod
go install -tags ledger ./...

sudo mv $HOME/go/bin/cantod /usr/bin/

cd $HOME/Canto
make install

# Initializes node
cantod init $MONIKER --chain-id canto_7700-1

# Sets seed node
sed -i 's/seeds = ""/seeds = "ade4d8bc8cbe014af6ebdf3cb7b1e9ad36f412c0@seeds.polkachu.com:15556"/' ~/.cantod/config/config.toml

# Sets service file
sudo cp $HOME/canto-node-primer/canto.service /etc/systemd/system/

# Config Files
if [ "$ENABLE_CORS" = "true" ]; then
  sed -i 's/cors_allowed_origins = \[\]/cors_allowed_origins = \["\*"\]/g' /$HOME/.cantod/config/config.toml
fi

if [ "$ENABLE_REST_API" = "true" ]; then
  sed -i 's/enable = false/enable = true/g' /$HOME/.cantod/config/app.toml
  sed -i 's/address = "tcp:\/\/0.0.0.0:1317"/address = "tcp:\/\/0.0.0.0:'$REST_API_PORT'"/g' /$HOME/.cantod/config/app.toml
fi

if [ "$PUBLIC_RPC" = "true" ]; then
  sed -i 's/laddr = "tcp:\/\/127.0.0.1:26657"/c\laddr = "tcp:\/\/0.0.0.0:'$RPC_PORT'"/g' $HOME/.cantod/config/config.toml
fi

# Syncs node
cd $HOME/canto-node-primer
chmod 700 state_sync.sh
./state_sync.sh

mkdir -p $HOME/.cantod/cosmovisor/genesis/bin
mkdir -p $HOME/.cantod/cosmovisor/upgrades
ln -s /usr/bin/cantod $HOME/.cantod/cosmovisor/genesis/bin/cantod

sudo service canto stop
sudo systemctl start canto && journalctl -u canto -f
