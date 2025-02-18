#!/bin/bash

VERSION=1.0.23
XANO_PORT=${XANO_PORT:-4201}
XANO_LICENSE="$XANO_LICENSE"
XANO_ORIGIN=${XANO_ORIGIN:-https://app.xano.com}
PULL=missing
MODE="-d"
ENTRYPOINT=""
INCOGNITO=0
VOLUME=""
VARS=${XANO_VARS:-settings}
ACTION="-help"
VERBOSE="/dev/null"
XANO_REPO=us-docker.pkg.dev/xano-registry/public/standalone
XANO_TAG=0.0.381

while :; do
  case $1 in
  "")
    break
    ;;
  -port)
    shift
    PORT=$1

    if [ "$PORT" = "" ]; then
      echo "Missing port"
      exit 1
    fi
    ;;
  -rmvol)
    ACTION=$1
    ;;
  -ver)
    echo $VERSION
    exit
    ;;
  -start)
    ACTION=$1
    ;;
  -stop)
    ACTION=$1
    ;;
  -vars)
    shift
    VARS=$1

    if [ "$VARS" = "XANO_VAR_FILE" ] && [ ! -f "$VARS" ]; then
      echo "Replace XANO_VAR_FILE with your actual file name."
      exit 1
    fi

    if [ "$VARS" = "" ]; then
      echo "Missing file"
      exit 1
    fi

    ;;
  -lic)
    shift
    XANO_LICENSE=$1

    if [ "$XANO_LICENSE" = "" ]; then
      echo "Missing license"
      exit 1
    fi
    ;;
  -verbose)
    shift
    VERBOSE="/dev/stdout"
    ;;
  -origin)
    shift
    ORIGIN=$1
    
    if [ "$ORIGIN" = "" ]; then
      echo "Missing origin"
      exit 1
    fi
    ;;
  -foreground)
    ACTION=-start
    MODE=""
    ;;
  -pull)
    ACTION=$1
    ;;
  -shell)
    ACTION=$1
    MODE="-it"
    ENTRYPOINT="--entrypoint=/bin/sh"
    VERBOSE="/dev/stdout"
    ;;
  -incognito)
    INCOGNITO=1
    ;;
  -connect)
    ACTION=$1
    VERB="exec"
    ;;
  -reset)
    ACTION=$1
    ;;
  -create)
    ACTION=$1
    shift

    echo -n "Enter in your license key: "
    read XANO_LICENSE

    if [ "$XANO_LICENSE" = "" ]; then
      echo "Missing license"
      exit 1
    fi

    while :; do
      echo "Creating Xano variable file"
      echo ""
      echo "Please enter a name for this file"
      echo -n "or leave blank to use the default: "
      read name

      if [ "$name" = "" ]; then
        name="settings"
      fi

      if [[ $name = *" "* ]]; then
        echo ""
        echo "### Please try again with no spaces."
        echo ""
      else
        break
      fi
    done

    printf "XANO_LICENSE=$XANO_LICENSE\nXANO_ORIGIN=$XANO_ORIGIN\nXANO_PORT=$XANO_PORT\nXANO_REPO=$XANO_REPO\nXANO_TAG=$XANO_TAG\n\n" > "$name.vars"

    echo ""
    echo "file created: $name.vars"
    echo ""
    echo "Continue to step 3 in our getting started guide."
    echo "https://go.xano.co/standalone-docs"
    echo ""

    exit 
    ;;
  -info)
    ACTION=$1
    ;;
  -renew)
    ACTION=$1
    ;;
  -delete-branch)
    ACTION=$1
    shift
    BRANCH_LABEL=$1

    if [ "$BRANCH_LABEL" = "" ]; then
      echo "Missing branch label"
      exit 1
    fi
    ;;
  -list-branch)
    ACTION=$1
    ;;
  -import-all)
    ACTION=$1
    shift
    IMPORT_FILE=$1

    if [ "$IMPORT_FILE" = "" ]; then
      echo "Missing file"
      exit 1
    fi
    ;;
  -import-workspace)
    ACTION=$1
    shift
    IMPORT_FILE=$1

    if [ "$IMPORT_FILE" = "" ]; then
      echo "Missing file"
      exit 1
    fi
    ;;
  -export-all)
    ACTION=$1
    ;;
  -export-workspace)
    ACTION=$1
    ;;
  -export-schema)
    ACTION=$1
    shift
    EXPORT_BRANCH=$1
    ;;
  -import-schema)
    ACTION=$1
    shift

    IMPORT_FILE=$1

    if [ "$IMPORT_FILE" = "" ]; then
      echo "Missing file"
      exit 1
    fi

    shift
    IMPORT_BRANCH=$1

    if [ "$IMPORT_BRANCH" = "" ]; then
      echo "Missing new branch label"
      exit 1
    fi

    shift
    IMPORT_SETLIVE=$1
    if [ "$IMPORT_SETLIVE" = "" ]; then
      echo "Missing setlive value - yes/no"
      exit 1
    fi
    ;;
  -help)
    ACTION=$1
    ;;
  esac
  shift
done

if [ "$ACTION" != "-help" ]; then
  if [[ $VARS != *".vars" ]]; then
    VARS="$VARS.vars"
  fi

  echo "Xano Standalone Edition $VERSION"
  echo "Using vars: $VARS"
  echo ""

  if [ ! -f "$VARS" ]; then
    echo "Vars file does not exist."
    echo ""
    exit 1
  fi

  source $VARS

  REPO=$XANO_REPO
  TAG=$XANO_TAG

  docker=$(which docker)

  if [ "$docker" = "" ]; then
    echo "Missing docker."
    exit
  fi

  CONTAINER="xano-"$XANO_LICENSE
fi

case "$ACTION" in
-help)
  echo "xano.sh $VERSION - Xano Standation (POC Edition) management"
  echo ""
  echo "Required parameters:"
  echo " -lic [arg:license, env:XANO_LICENSE]"
  echo "    the xano license, e.g. d4e7aa6c-cdbc-40e4..."
  echo ""
  echo "Optional parameters:"
  echo " -vars [arg:file, default: ./settings.vars]"
  echo "    a file consisting of xano variables"
  echo " -port [arg:port, env:XANO_PORT, default: 4200]"
  echo "    web port"
  echo " -origin [arg:origin, env:XANO_ORIGIN, default: https://app.xano.com]"
  echo "    the xano master origin"
  echo " -tag [arg:tag, default: latest]"
  echo "    the docker image tag"
  echo " -create"
  echo "    create a vars file for your xano standalone license"
  echo " -rmvol"
  echo "    remove the volume, if it exists"
  echo " -pull"
  echo "    pull the latest standalone docker image"
  echo " -incognito"
  echo "    skip creating a volume, so everything is cleared once the container exits"
  echo " -foreground"
  echo "    run in the foreground"
  echo " -start"
  echo "    start in the background, or re-start if it is running"
  echo " -stop"
  echo "    stop the background process, if it is running"
  echo " -shell"
  echo "    run a shell instead of normal entrypoint (this requires no active container)"
  echo " -connect"
  echo "    run a shell into the existing container"
  echo " -ver"
  echo "    display the shell script version"
  echo " -export-all"
  echo "    export admin credentials, database tables, records, branches, and media"
  echo " -import-all [arg:file]"
  echo "    replace the entire environment with the new import"
  echo " -export-workspace"
  echo "    export the workspace's database tables, records, live branch, and media"
  echo " -import-workspace [arg:file]"
  echo "    replace the existing workspace with the new import"
  echo " -export-schema [arg:branch, default: live branch]"
  echo "    export the database table + branch schema"
  echo " -import-schema [arg:file] [arg:newbranch] [arg:setlive]"
  echo "    import schema into a new branch and optionally set it live"
  echo " -reset"
  echo "    reset workspace"
  echo " -info"
  echo "    get details about the license"
  echo " -renew"
  echo "    renew the license"
  echo " -verbose"
  echo "    show additional logging messages for debugging"
  echo " -help"
  echo "    display this menu"
  echo ""
  exit
  ;;
-rmvol)
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -eq 0 ]; then
    echo "stopping"
    docker stop -t 3 $CONTAINER >/dev/null
    sleep 1
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
  ;;
-pull)
  RESTART=0

  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -eq 0 ]; then
    echo "stopping"
    docker stop -t 3 $CONTAINER >/dev/null
    sleep 1
    RESTART=1
  fi

  docker pull $REPO:$TAG

  echo "update complete"

  if [ "$RESTART" = "1" ]; then
    echo "starting"
    ACTION="-start"
  else
    exit
  fi
  ;;
-stop)
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
  ;;
-start)
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -eq 0 ]; then
    docker stop -t 3 $CONTAINER >/dev/null
    echo "restarting"
    sleep 1
  fi
  ;;
-shell)
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -eq 0 ]; then
    echo "A container is already in use. Try using -connect instead."
    exit 1
  fi
  ;;
-info)
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "not running"
    exit 1
  fi

  docker \
    exec \
    $CONTAINER \
    php /xano/bin/tools/standalone/info.php
  exit
  ;;
-renew)
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "not running"
    exit 1
  fi

  ret=$(docker exec $CONTAINER php /xano/bin/tools/standalone/renew.php)

  if [ "$ret" != "ok" ]; then
    echo "$ret"
    exit 1
  fi

  docker \
    exec \
    $CONTAINER \
    php /xano/bin/tools/standalone/info.php
  exit
  ;;
-export-all)
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "not running"
    exit 1
  fi

  export=$(docker \
    exec \
    $CONTAINER \
    php /xano/bin/tools/standalone/export-all.php)
  ret=$?

  if [ $ret -ne 0 ]; then
    echo "Error: $export"
    exit 1
  fi

  docker cp $CONTAINER:$export $(basename $export)
  exit
  ;;
-export-workspace)
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "not running"
    exit 1
  fi

  export=$(docker \
    exec \
    $CONTAINER \
    php /xano/bin/tools/standalone/export-workspace.php)
  ret=$?

  if [ $ret -ne 0 ]; then
    echo "Error: $export"
    exit 1
  fi

  docker cp $CONTAINER:$export $(basename $export)
  exit
  ;;
-export-schema)
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "not running"
    exit 1
  fi

  export=$(docker \
    exec \
    $CONTAINER \
    php /xano/bin/tools/standalone/export-schema.php --branch "$EXPORT_BRANCH")
  ret=$?

  if [ $ret -ne 0 ]; then
    echo "Error: $export"
    exit 1
  fi

  docker cp $CONTAINER:$export $(basename $export)
  exit
  ;;
-import-schema)
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "not running"
    exit 1
  fi

  docker cp $(realpath $IMPORT_FILE) $CONTAINER:/tmp/import.tar.gz > /dev/null

  docker \
    exec \
    $CONTAINER \
    php /xano/bin/tools/standalone/import-schema.php --file /tmp/import.tar.gz --newbranch "$IMPORT_BRANCH" --setlive "$IMPORT_SETLIVE"
  exit
  ;;
-reset)
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "not running"
    exit 1
  fi

  export=$(docker \
    exec \
    $CONTAINER \
    php /xano/bin/tools/standalone/reset.php)
  ret=$?

  if [ $ret -ne 0 ]; then
    echo "Error: $export"
    exit 1
  fi

  echo "reset"
  exit
  ;;
-import-all)
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "not running"
    exit 1
  fi

  docker cp $(realpath $IMPORT_FILE) $CONTAINER:/tmp/import.tar.gz > /dev/null

  docker \
    exec \
    $CONTAINER \
    php /xano/bin/tools/standalone/import-all.php --file /tmp/import.tar.gz
  exit
  ;;
-import-workspace)
  ret=$(docker container inspect $CONTAINER 2>&1 >/dev/null)
  ret=$?
  if [ $ret -ne 0 ]; then
    echo "not running"
    exit 1
  fi

  docker cp $(realpath $IMPORT_FILE) $CONTAINER:/tmp/import.tar.gz > /dev/null

  docker \
    exec \
    $CONTAINER \
    php /xano/bin/tools/standalone/import-workspace.php --file /tmp/import.tar.gz
  exit
  ;;
-connect)
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
  exit
  ;;
esac

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
  $REPO:$TAG > $VERBOSE

if [ "$ACTION" = "-start" ]; then
  sleep 1
  docker \
    exec \
    $CONTAINER \
    php /xano/bin/tools/standalone/ready.php
fi
