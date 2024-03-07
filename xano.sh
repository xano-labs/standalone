#!/bin/bash

VERSION=1.0.3
XANO_PORT=${XANO_PORT:-4200}
XANO_INSTANCE="$XANO_INSTANCE"
XANO_TOKEN="$XANO_TOKEN"
XANO_DOMAIN=${XANO_DOMAIN:-app.xano.com}
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
VARS=0
RMVOL=0
STOP=0
CREDENTIALS=0

while :; do
  case $1 in
  "")
    break
    ;;
  -port)
    shift
    PORT=$1
    ;;
  -rmvol)
    RMVOL=1
    ;;
  -credentials)
    CREDENTIALS=1
    ;;
  -ver)
    echo $VERSION
    exit
    ;;
  -stop)
    STOP=1
    ;;
  -vars)
    shift
    VARS=$1
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

if [ "$VARS" != "0" ]; then
  if [ ! -f "$VARS" ]; then
    echo "Vars file does not exist."
    echo ""
    exit 1
  fi

  source $VARS
fi

if [ "$NOTICE" = "1" ]; then
  if [ "$XANO_INSTANCE" != "" ] && [ "$XANO_TOKEN" != "" ]; then
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
  echo " -vars: a variable file"
  echo " -port: web port, default: 4200"
  echo "    env: XANO_PORT"
  echo " -domain: the xano master domain, default: app.xano.com"
  echo "    env: XANO_DOMAIN"
  echo " -tag: the docker image tag, default: latest"
  echo " -rmvol: remove the volume, if it exists"
  echo " -nopull: skip pulling the latest docker image"
  echo " -stop: stop the daemon, if it is running"
  echo " -incognito: skip creating a volume, so everything is cleared once the container exits"
  echo " -daemon: run in the background"
  echo " -shell: run a shell instead of normal entrypoint (this requires no active container)"
  echo " -connect: run a shell into the existing container"
  echo " -credentials: retrieve the initial credentials"
  echo " -ver: display the shell script version"
  echo " -help: display this menu"
  exit 1
fi

if [ "$SHELL" = 1 ] && [ "$DAEMON" = 1 ]; then
  echo "Run either as shell or daemon."
  exit 1
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

CONTAINER="xano-"$XANO_INSTANCE

if [ "$RMVOL" = "1" ]; then
  ret=$(docker volume inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?

  if [ $ret -ne 0 ]; then
    echo "volume already removed"
  else
    docker volume rm $CONTAINER 2>/dev/null > /dev/null
    echo "volume removed"
  fi
  exit
fi

if [ "$STOP" = "1" ]; then
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -eq 0 ]; then
    docker kill $CONTAINER > /dev/null
    echo "daemon stopped"
  else
    echo "daemon not running"
  fi
  exit
fi

if [ "$CREDENTIALS" = "1" ]; then
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -eq 0 ]; then
    echo "INITIAL CREDENTIALS"
    echo ""
    echo "Note: These are no longer valid after first login."
    echo ""
    echo "Email:    "$(docker exec $CONTAINER sh -c 'cat /xano/storage/xano.yaml | yq .standalone.email')
    echo "Password: "$(docker exec $CONTAINER sh -c 'cat /xano/storage/xano.yaml | yq .standalone.password')
    echo "Origin:   http://localhost:$XANO_PORT"
    echo ""
    exit 1
  else
    echo "There is no existing container running."
    echo ""
    exit 1
  fi
fi

if [ "$CONNECT" = "0" ]; then
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -eq 0 ]; then
    echo "Existing container is already running."
    echo "Is this intentional? If not, run the following command to remove it:"
    echo ""
    echo "  docker kill $CONTAINER"
    echo ""
    exit 1
  fi
else
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -eq 1 ]; then
    echo "There is no existing container running."
    echo ""
    exit 1
  fi
fi

if [ "$INCOGNITO" = "0" ]; then
  ret=$(docker volume inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?

  if [ $ret -ne 0 ]; then
    echo "creating docker volume"
    docker volume create $CONTAINER 2>&1 >/dev/null
    ret=$?
    if [ $ret -ne 0 ]; then
      echo "unable to create volume"
      exit
    fi
  fi
  VOLUME="-v $CONTAINER:/xano/storage"
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
    -p 0.0.0.0:$XANO_PORT:80 \
    --pull $PULL \
    -e "XANO_INSTANCE=$XANO_INSTANCE" \
    -e "XANO_TOKEN=$XANO_TOKEN" \
    -e "XANO_MASTER=$XANO_DOMAIN" \
    $VOLUME \
    $IMAGE:$TAG
fi
