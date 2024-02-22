#!/bin/bash

PORT=4200
NAME=
DOMAIN=app.xano.com
IMAGE=gcr.io/xano-registry/standalone
TAG=latest
PULL=missing
INDEX=0

while :; do
  case $1 in
  "")
    break
    ;;
  -port)
    shift
    PORT=$1
    ;;
  -name)
    shift
    NAME=$1
    ;;
  -domain)
    shift
    DOMAIN=$1
    ;;
  -index)
    shift
    INDEX=$1
    ;;
  esac
  shift
done

if [ "$NAME" = "" ]; then
  echo "Xano Standalone Edition"
  echo ""
  echo "Required parameters:"
  echo " -name: xano instance name, e.g. x123-abcd-1234"
  echo ""
  echo "Optional parameters:"
  echo " -port: web port, default: 4200"
  echo " -domain: the xano master domain, default: app.xano.com"
  echo " -tag: the docker image tag, default: latest"
  echo " -index: the index for parallel instances, default: 0"
  exit
fi

if [ "$TAG" = "latest" ]; then
  PULL="always"
fi

pwd=$(cd "$(dirname "$0")" && pwd -P)

docker=$(which docker)

if [ "$docker" = "" ]; then
  echo "Missing docker."
  exit
fi

CONTAINER="xano-"$NAME"-"$INDEX

VOLUME=$CONTAINER

ret=$(docker volume inspect $VOLUME 2>&1 >/dev/null)
ret=$?

if [ $ret -ne 0 ]; then
  echo "creating docker volume"
  docker volume create $VOLUME 2>&1 >/dev/null
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "unable to create volumne"
    exit
  fi
fi

ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
ret=$?
if [ $ret -eq 0 ]; then
  echo "Existing container is already running."
  echo "Try using the -index param."
  exit
fi

docker \
  run \
  --name $CONTAINER \
  --rm \
  -p 0.0.0.0:$PORT:80 \
  --pull $PULL \
  -e "XANO_INSTANCE=$NAME" \
  -e "XANO_MASTER=$DOMAIN" \
  -v $VOLUME:/xano/storage \
  $IMAGE:$TAG

