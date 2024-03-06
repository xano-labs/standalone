#!/bin/bash

PORT=${XANO_PORT:-4200}
INSTANCE="$XANO_INSTANCE"
TOKEN="$XANO_TOKEN"
DOMAIN=${XANO_DOMAIN:-app.xano.com}
IMAGE=gcr.io/xano-registry/standalone
TAG=latest
PULL=missing
NOPULL=0
DAEMON=0
SHELL=0
MODE=""
ENTRYPOINT=""
NOTICE=1
INCOGNITO=0
VOLUME=""
CONNECT=0

while :; do
  case $1 in
  "")
    break
    ;;
  -port)
    shift
    PORT=$1
    ;;
  -instance)
    shift
    INSTANCE=$1
    ;;
  -token)
    shift
    TOKEN=$1
    ;;
  -domain)
    shift
    DOMAIN=$1
    ;;
  -daemon)
    DAEMON=1
    MODE="-d"
    ;;
  -nopull)
    NOPULL=1
    ;;
  -shell)
    SHELL=1
    MODE="-it"
    ENTRYPOINT="--entrypoint=/bin/sh"
    NOTICE=0
    ;;
  -incognito)
    INCOGNITO=1
    ;;
  -connect)
    CONNECT=1
    VERB="exec"
    ;;
  -help)
    NOTICE=1
    INSTANCE=""
    TOKEN=""
    ;;
  esac
  shift
done

if [ "$NOTICE" = "1" ]; then
  if [ "$INSTANCE" != "" ] || [ "$TOKEN" != "" ]; then
    NOTICE=0
  fi
fi

if [ "$NOTICE" = "1" ]; then
  echo "Xano Standalone Edition"
  echo ""
  echo "Required parameters:"
  echo " -instance: xano instance name, e.g. x123-abcd-1234"
  echo "    env: XANO_INSTANCE"
  echo " -token: your metadata api token - env: XANO_TOKEN"
  echo "    env: XANO_TOKEN"
  echo ""
  echo "Optional parameters:"
  echo " -port: web port, default: 4200"
  echo "    env: XANO_PORT"
  echo " -domain: the xano master domain, default: app.xano.com"
  echo "    env: XANO_DOMAIN"
  echo " -tag: the docker image tag, default: latest"
  echo " -nopull: skip pulling the latest docker image"
  echo " -incognito: skip creating a volume, so everything is cleared once the container exits"
  echo " -daemon: run in the background"
  echo " -shell: run a shell instead of normal entrypoint (this requires no active container)"
  echo " -connect: run a shell into the existing container"
  echo " -help: display this menu"
  exit
fi

if [ "$SHELL" = 1 ] && [ "$DAEMON" = 1 ]; then
  echo "Run either as shell or daemon."
  exit
fi

if [ "$TAG" = "latest" ] && [ "$NOPULL" = "0" ]; then
  PULL="always"
fi

pwd=$(cd "$(dirname "$0")" && pwd -P)

docker=$(which docker)

if [ "$docker" = "" ]; then
  echo "Missing docker."
  exit
fi

CONTAINER="xano-"$INSTANCE

if [ "$CONNECT" = "0" ]; then
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -eq 0 ]; then
    echo "Existing container is already running."
    echo "Is this intentional? If not, run the following command to remove it:"
    echo ""
    echo "  docker kill $CONTAINER"
    echo ""
    exit
  fi
else
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -eq 1 ]; then
    echo "There is no existing container running."
    echo ""
    exit
  fi
fi

if [ "$CONNECT" = "1" ]; then
  docker \
    exec \
    -it \
    $CONTAINER \
    /bin/sh
else
  docker \
    run \
    --name $CONTAINER \
    --rm \
    $MODE \
    $ENTRYPOINT \
    -p 0.0.0.0:$PORT:80 \
    --pull $PULL \
    -e "XANO_INSTANCE=$INSTANCE" \
    -e "XANO_TOKEN=$TOKEN" \
    -e "XANO_MASTER=$DOMAIN" \
    $VOLUME \
    $IMAGE:$TAG
fi
