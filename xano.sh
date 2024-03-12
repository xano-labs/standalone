#!/bin/bash

VERSION=1.0.9
XANO_PORT=${XANO_PORT:-4200}
XANO_LICENSE="$XANO_LICENSE"
XANO_ORIGIN=${XANO_ORIGIN:-https://app.xano.com}
IMAGE=gcr.io/xano-registry/standalone
TAG=latest
PULL=missing
NOPULL=0
DAEMON=0
SHELL=0
MODE="-d"
ENTRYPOINT=""
NOTICE=1
INCOGNITO=0
VOLUME=""
CONNECT=0
VARS=./settings.vars
RMVOL=0
STOP=0
HELP=0
CREDENTIALS=0
WITH_BRANCH=""
WITH_FILES="0"
WITH_RECORDS="0"

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
    NOTICE=0
    ;;
  -credentials)
    CREDENTIALS=1
    NOTICE=0
    ;;
  -ver)
    echo $VERSION
    exit
    ;;
  -start)
    DAEMON=1
    NOTICE=0
    ;;
  -stop)
    STOP=1
    NOTICE=0
    ;;
  -vars)
    shift
    VARS=$1
    ;;
  -lic)
    shift
    XANO_LICENSE=$1
    ;;
  -origin)
    shift
    ORIGIN=$1
    ;;
  -foreground)
    DAEMON=0
    NOTICE=0
    MODE=""
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
    NOTICE=0
    INCOGNITO=1
    ;;
  -connect)
    CONNECT=1
    NOTICE=0
    DAEMON=0
    VERB="exec"
    ;;
  -export)
    EXPORT=1
    NOTICE=0
    VERB="exec"
    ;;
  -with-branch)
    shift
    WITH_BRANCH=$1
    ;;
  -with-files)
    WITH_FILES="1"
    ;;
  -with-records)
    WITH_RECORDS="1"
    ;;
  -help)
    NOTICE=1
    HELP=1
    ;;
  esac
  shift
done

echo "Xano Standalone Edition $VERSION"
echo "Using vars: $VARS"
echo ""

if [ ! -f "$VARS" ]; then
  echo "Vars file does not exist."
  echo ""
  exit 1
fi

source $VARS

if [ "$NOTICE" = "1" ]; then
  echo "Required parameters:"
  echo " -lic [arg, env:XANO_LICENSE]: the xano license, e.g. d4e7aa6c-cdbc-40e4..."
  echo ""
  echo "Optional parameters:"
  echo " -vars [arg]: a variable file, default: ./settings.vars"
  echo " -port [arg, env:XANO_PORT]: web port, default: 4200"
  echo " -origin [arg, env:XANO_ORIGIN]: the xano master origin, default: https://app.xano.com"
  echo " -tag [arg]: the docker image tag, default: latest"
  echo " -rmvol: remove the volume, if it exists"
  echo " -nopull: skip pulling the latest docker image"
  echo " -incognito: skip creating a volume, so everything is cleared once the container exits"
  echo " -foreground: run in the foreground"
  echo " -start: start in the background, or re-start if it is running"
  echo " -stop: stop the background process, if it is running"
  echo " -shell: run a shell instead of normal entrypoint (this requires no active container)"
  echo " -connect: run a shell into the existing container"
  echo " -credentials: retrieve the initial credentials"
  echo " -ver: display the shell script version"
  echo " -export: export the workspace - schema and business logic only"
  echo " -with-branch [arg]: specify the branch to use - otherwise, the live branch will be used"
  echo " -with-records: include database records with the export"
  echo " -with-files: include media storage with the export"
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

CONTAINER="xano-"$XANO_LICENSE

if [ "$RMVOL" = "1" ]; then
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -eq 0 ]; then
    docker stop -t 3 $CONTAINER >/dev/null
    sleep 1
    docker ps
  fi

  ret=$(docker volume inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?

  if [ $ret -ne 0 ]; then
    echo "volume already removed"
  else
    docker volume rm $CONTAINER 2>/dev/null >/dev/null
    echo "volume removed"
  fi
  exit
fi

if [ "$STOP" = "1" ]; then
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -eq 0 ]; then
    docker stop -t 3 $CONTAINER >/dev/null
    echo "stopped"
    sleep 1
  else
    echo "not running"
  fi
  exit
fi

if [ "$DAEMON" = "1" ]; then
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -eq 0 ]; then
    docker stop -t 3 $CONTAINER >/dev/null
    echo "restarting"
    sleep 1
  fi
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

if [ "$EXPORT" = "1" ]; then
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "not running"
    exit 1
  fi

  export=$(docker \
    exec \
    $CONTAINER \
    php /xano/bin/tools/standalone/export.php --branch "$WITH_BRANCH" --records "$WITH_RECORDS" --files "$WITH_FILES")
  ret=$?

  if [ $ret -ne 0 ]; then
    echo "Error: $export"
    exit 1
  fi

  docker cp $CONTAINER:$export $(basename $export)
elif [ "$CONNECT" = "1" ]; then
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "not running"
    exit 1
  fi

  docker \
    exec \
    -it \
    $CONTAINER \
    /bin/sh
else
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -eq 0 ]; then
    echo "already running"
    exit 1
  fi

  docker \
    run \
    --name $CONTAINER \
    --rm \
    $MODE \
    $ENTRYPOINT \
    -p 0.0.0.0:$XANO_PORT:80 \
    --pull $PULL \
    -e "XANO_LICENSE=$XANO_LICENSE" \
    -e "XANO_ORIGIN=$XANO_ORIGIN" \
    -e "XANO_PORT=$XANO_PORT" \
    $VOLUME \
    $IMAGE:$TAG

  if [ "$DAEMON" = "1" ]; then
    sleep 1
    docker \
      exec \
      $CONTAINER \
      php /xano/bin/tools/standalone/ready.php
  fi
fi
