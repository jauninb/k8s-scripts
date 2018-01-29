#!/bin/bash

if ! kubectl --namespace otc-dev rollout status -w deployment/docker; then
  echo "Installing Docker Server into build clsuter.."
  kubectl --namespace otc-dev run docker --image=docker:dind --overrides='{ "apiVersion": "extensions/v1beta1", "spec": { "template": { "spec": {"containers": [ { "name": "docker", "image": "docker:dind", "securityContext": { "privileged": true } } ] } } } }'
  kubectl --namespace otc-dev rollout status -w deployment/docker
fi

kubectl --namespace otc-dev port-forward $(kubectl --namespace otc-dev get pods | grep docker | awk '{print $1;}') 2375:2375 > /dev/null 2>&1 &

echo "installing docker client"
sudo apt-get -y install apt-transport-https ca-certificates 
sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
sudo add-apt-repository "deb https://apt.dockerproject.org/repo ubuntu-precise main"
sudo apt-get update
sudo apt-get -y install docker-engine

export DOCKER_HOST='tcp://localhost:2375'

bx cr login

echo "Discovery Registry..."
CCS_REGISTRY_HOST=$(bx cr info | grep 'Container Registry  ' | awk '{print $3};')
echo "Found: $CCS_REGISTRY_HOST"

if [ -f ".k8s_build_id" ]; then
      APPLICATION_VERSION="$(<.k8s_build_id)"
else
      APPLICATION_VERSION="$(<.pipeline_build_id)"
fi

if [ -z "$BUILD_NUMBER" ]; then
  echo "Giving image build number: $APPLICATION_VERSION"
  BUILD_NUMBER=$APPLICATION_VERSION
else
  echo "Giving iamge a non tag build number: $BUILD_NUMBER"
fi
