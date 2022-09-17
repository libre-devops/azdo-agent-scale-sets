#!/usr/bin/env bash

LSB_RELEASE=$(lsb_release -rs)
USER=$(whoami)

echo -en "\n" | /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bash_profile && \
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.bashrc && \
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && \
    source "/home/${USER}/.bash_profile" && source "/home/${USER}/.bashrc" && \
    brew install gcc python3 packer terraform && pip3 install ansible-core azure-cli

# Install Microsoft repository
wget https://packages.microsoft.com/config/ubuntu/$LSB_RELEASE/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# Install Microsoft GPG public key
curl -L https://packages.microsoft.com/keys/microsoft.asc | apt-key add -

curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg

# update
sudo apt-get -yq update
sudo apt-get -yq dist-upgrade

# Check to see if docker is already installed
docker_package=moby
echo "Determing if Docker ($docker_package) is installed"
if ! IsPackageInstalled $docker_package; then
    echo "Docker ($docker_package) was not found. Installing..."
    sudo apt-get remove -y moby-engine moby-cli
    sudo apt-get update
    sudo apt-get install -y moby-engine moby-cli
    sudo apt-get install --no-install-recommends -y moby-buildx
    sudo apt-get install -y moby-compose
else
    echo "Docker ($docker_package) is already installed"
fi

# Enable docker.service
sudo systemctl is-active --quiet docker.service || sudo systemctl start docker.service
sudo systemctl is-enabled --quiet docker.service || sudo systemctl enable docker.service

# Docker daemon takes time to come up after installing
sleep 10
docker info

# Always attempt to logout so we do not leave our credentials on the built
# image. Logout _should_ return a zero exit code even if no credentials were
# stored from earlier.
docker logout

###########################################################################################################################################

USER="actions"
REPO="runner"
OS="linux"
ARCH="x64"
PACKAGE="tar.gz"
ACTIONS_URL="https://github.com/libre-devops/azdo-agent-scale-sets"
TOKEN="blah"

runnerLatestAgentVersion="$(curl --silent "https://api.github.com/repos/${USER}/${REPO}/releases/latest" | jq -r .tag_name)"
strippedTagRunnerAgentVersion="$(echo "${runnerLatestAgentVersion}" | sed 's/v//')" && \
runnerPackageUrl="https://github.com/${USER}/${REPO}/releases/download/${runnerLatestAgentVersion}/actions-runner-${OS}-${ARCH}-${strippedTagRunnerAgentVersion}.${PACKAGE}"
actionsPackageName="actions-runner-${OS}-${ARCH}-${strippedTagRunnerAgentVersion}.${PACKAGE}"
curl -o "${actionsPackageName}" -L "${runnerPackageUrl}"
tar xzf "${actionsPackageName}" && rm -rf "${actionsPackageName}"
./config.sh --url "${ACTIONS_URL}" --token "${TOKEN}" && \
./run.sh --unattended &

