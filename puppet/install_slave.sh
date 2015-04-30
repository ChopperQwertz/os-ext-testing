#! /usr/bin/env bash

# Sets up a slave Jenkins server intended to run devstack-based Jenkins jobs

set -e

THIS_DIR=`pwd`

DATA_REPO_INFO_FILE=$THIS_DIR/.data_repo_info
DATA_PATH=$THIS_DIR/os-ext-testing-data
OSEXT_PATH=$THIS_DIR/os-ext-testing
OSEXT_REPO=https://github.com/rasselin/os-ext-testing
PUPPET_MODULE_PATH="--modulepath=$OSEXT_PATH/puppet/modules:/root/system-config/modules:/etc/puppet/modules"

if ! sudo test -d /root/system-config; then
  sudo git clone https://review.openstack.org/p/openstack-infra/system-config.git \
    /root/system-config
fi

if ! sudo test -d /root/project-config; then
  sudo git clone https://github.com/openstack-infra/project-config.git \
    /root/project-config
fi

# Install Puppet and the OpenStack Infra Config source tree
# TODO(Ramy) Make sure sudo has http proxy settings...
if [[ ! -e install_puppet.sh ]]; then
  wget https://git.openstack.org/cgit/openstack-infra/system-config/plain/install_puppet.sh
  sudo bash -xe install_puppet.sh
  sudo /bin/bash /root/system-config/install_modules.sh
fi

# Update /root/system-config
echo "Update system-config"
sudo git  --work-tree=/root/system-config/ --git-dir=/root/system-config/.git remote update
sudo git  --work-tree=/root/system-config/ --git-dir=/root/system-config/.git pull

echo "Update project-config"
sudo git  --work-tree=/root/project-config/ --git-dir=/root/project-config/.git remote update
sudo git  --work-tree=/root/project-config/ --git-dir=/root/project-config/.git pull

# Clone or pull the the os-ext-testing repository
if [[ ! -d $OSEXT_PATH ]]; then
    echo "Cloning os-ext-testing repo..."
    git clone $OSEXT_REPO $OSEXT_PATH
fi

if [[ "$PULL_LATEST_OSEXT_REPO" == "1" ]]; then
    echo "Pulling latest os-ext-testing repo master..."
    cd $OSEXT_PATH; git checkout master && sudo git pull; cd $THIS_DIR
fi

if [[ ! -e $DATA_PATH ]]; then
    echo "Enter the URI for the location of your config data repository. Example: https://github.com/rasselin/os-ext-testing-data"
    read data_repo_uri
    if [[ "$data_repo_uri" == "" ]]; then
        echo "Data repository is required to proceed. Exiting."
        exit 1
    fi
    git clone $data_repo_uri $DATA_PATH
fi

if [[ "$PULL_LATEST_DATA_REPO" == "1" ]]; then
    echo "Pulling latest data repo master."
    cd $DATA_PATH; git checkout master && git pull; cd $THIS_DIR;
fi

# Pulling in variables from data repository
. $DATA_PATH/vars.sh

CLASS_ARGS="ssh_key => '$JENKINS_SSH_PUBLIC_KEY_NO_WHITESPACE', "
sudo puppet apply --verbose $PUPPET_MODULE_PATH -e "class {'os_ext_testing::devstack_slave': $CLASS_ARGS }"

if [[ ! -e /opt/git ]]; then
    sudo mkdir -p /opt/git
    sudo -i python /opt/nodepool-scripts/cache_git_repos.py http://git.openstack.org
    sudo /opt/nodepool-scripts/prepare_devstack.sh
fi
