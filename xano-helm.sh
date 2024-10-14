#!/bin/bash

set -e

VERSION=1.0.6
ACTION="help"
HELM_RELEASE=xano-instance
XANO_ORIGIN=${XANO_ORIGIN:-https://app.xano.com}

SRC=""

check_script() {
  set +e
  RET=$(which "$1")
  if [ "$RET" = "" ]; then
    echo "Please install: $1"
    exit 1
  fi
  set -e
}

check_script curl
check_script yq
check_script helm
check_script kubectl
check_script kubectl

get_arg() {
  arg=$1
  shift

  set -e

  while :; do
    case $1 in
    "")
      break
      ;;
    "$arg")
      shift

      if [ "$1" = "" ]; then
        echo "Missing value for param: $arg" >&2
        exit 1
      fi

      echo "$1"

      set +e

      exit
      ;;
    esac
    shift
  done

  echo "Missing param: $arg" >&2
  exit 1
}

validate() {
  if [ "$2" = "" ]; then
    echo "validate: Missing second argument" >&2
    exit 1
  fi

  if [ "$1" = "" ]; then
    echo "$2" >&2
    exit 1
  fi
}

get_license() {
  echo $(yq ".license.id" $1)
}

get_name() {
  echo $(yq ".name" $1)
}

get_origin() {
  echo $(yq ".origin" $1)
}

get_email() {
  echo $(yq ".email" $1)
}

get_clusterIssuer() {
  echo $(yq ".k8s.clusterIssuer" $1)
}

get_result_file() {
  echo ./$(get_license $1).yaml
}

get_namespace() {
  echo $(yq ".k8s.namespace" $1)
}

get_release() {
  echo $(yq ".release" $1)
}

validate_file() {
  if [ "$1" = "" ] || [ "$1" = "CHANGE_ME" ]; then
    echo "Missing file: $1"
    exit 1
  fi

  if [[ $1 == "http://"* ]] || [[ $1 == "https://"* ]]; then
    return
  fi

  if [ ! -f "$1" ]; then
    echo "File does not exist - $1"
    exit 1
  fi
}

get_file() {
  if [ -f "$1" ]; then
    cat "$1"
  else
    if [[ $1 == "http://"* ]] || [[ $1 == "https://"* ]]; then
      RET=$(curl --fail "$1" 2>/dev/null)
      if [ "$RET" = "" ]; then
        echo "Unable to download: $1" >&2
        exit 1
      fi
      echo "$RET"
    else
      echo "Unknown error."
      exit 1
    fi
  fi
}

validate_license() {
  validate_file "$1"

  RET=$(yq ".license.id" $1)

  if [ "$RET" = "null" ] || [ "$RET" = "" ]; then
    echo "Invalid license file"
    exit 1
  fi

  RET=$(yq ".license.type" $1)

  if [ "$RET" != "helm" ]; then
    echo "Wrong license type."
    exit 1
  fi
}

validate_config() {
  validate_file "$1"

  RET=$(yq ".host" $1)

  if [ "$RET" = "null" ]; then
    echo "Invalid config file"
    exit 1
  fi
}

validate_clusterissuer() {
  RET=$(echo "$1" | yq ".kind")

  if [ "$RET" != "ClusterIssuer" ]; then
    echo "Invalid cluster issuer"
    exit 1
  fi
}

package() {
  LIC=$1
  CFG=$2

  BASE=https://gitlab.com/xano/standalone/-/raw/main/data/base.yaml
  BASE_DATA=$(get_file $BASE)

  EXTRAS=https://gitlab.com/xano/standalone/-/raw/main/data/extras.yaml
  EXTRAS_DATA=$(get_file $EXTRAS)

  RESULT=$(get_result_file $LIC)

  echo "$BASE_DATA" > $RESULT

  yq -i '.xano.db = load("'$CFG'").database.credentials' $RESULT

  INGRESS_TYPE=$(yq .k8s.ingressType $CFG)

  if [ "$INGRESS_TYPE" = "null" ]; then
    echo "Missing ingressType."
    exit 1
  fi

  DEPLOYMENT=$(echo "$EXTRAS_DATA" | yq '.ingress["'$INGRESS_TYPE'"].deployment' -o j)

  yq -i '.xano.db = load("'$CFG'").database.credentials' $RESULT
  yq -i '.xano.redis = load("'$CFG'").redis.credentials' $RESULT
  yq -i '.xano.k8s.namespace.name = load("'$CFG'").k8s.namespace' $RESULT
  yq -i '.xano.k8s.limit.database = load("'$CFG'").database.settings' $RESULT
  yq -i '.xano.k8s.limit.apc = load("'$CFG'").apc' $RESULT
  yq -i '.xano.k8s.storage.cloud = load("'$CFG'").storage.public' $RESULT
  yq -i '.xano.k8s.storage.private_cloud = load("'$CFG'").storage.private' $RESULT
  yq -i '.xano.id = "xano://" + load("'$CFG'").license' $RESULT
  yq -i '.xano.security = load("'$CFG'").security' $RESULT
  yq -i '.xano.sodium = load("'$CFG'").sodium' $RESULT
  yq -i '.xano.node.workers = load("'$CFG'").node.workers' $RESULT
  yq -i '.xano.auth.secret.k = load("'$CFG'").auth.secret' $RESULT
  yq -i '.xano.auth.entraid = load("'$CFG'").auth.entraid' $RESULT
  yq -i '.xano.k8s.ingress.primary.tls.host = load("'$CFG'").host' $RESULT
  yq -i '.xano.k8s.ingress.primary.host = load("'$CFG'").host' $RESULT
  yq -i '.xano.k8s.ingress.primary.clusterIssuer = load("'$CFG'").k8s.clusterIssuer' $RESULT
  yq -i '.xano.k8s.ingress.class = load("'$CFG'").k8s.ingressClass' $RESULT
  yq -i '.xano.k8s.ingress.annotations = load("'$CFG'").k8s.ingressAnnotations' $RESULT
  yq -i '.xano.k8s.ingress.type = "'$INGRESS_TYPE'"' $RESULT
  yq -i ".xano.k8s.ingress.deployment = $DEPLOYMENT" $RESULT

  yq -i '.xano.k8s.deployments.redis.storage.class = load("'$CFG'").k8s.storageClass' $RESULT
  yq -i '.xano.k8s.deployments.database.storage.class = load("'$CFG'").k8s.storageClass' $RESULT
  yq -i '.xano.blob.url.origin = "https://" + load("'$CFG'").host' $RESULT
  yq -i '.xano.package.name = "enterprise"' $RESULT

  yq -i '.xano.k8s.deployments.redis.containers.redis.settings = load("'$CFG'").resources.redis.settings' $RESULT
  yq -i '.xano.k8s.deployments.redis.containers.redis.settings.requirepass = load("'$CFG'").redis.credentials.password' $RESULT

  KEYS=("backend" "realtime" "frontend" "node" "task" "redis" "database")
  for KEY in "${KEYS[@]}"
  do
    yq -i '.xano.k8s.deployments.'$KEY'.enabled = load("'$CFG'").resources.'$KEY'.enabled' $RESULT
    yq -i '.xano.k8s.deployments.'$KEY'.containers.'$KEY'.resources.limits = (load("'$CFG'").resources.'$KEY'.limits | with_entries(select(.key == "cpu" or .key == "memory")) )' $RESULT
    yq -i '.xano.k8s.deployments.'$KEY'.containers.'$KEY'.resources.requests = (load("'$CFG'").resources.'$KEY'.requests | with_entries(select(.key == "cpu" or .key == "memory")) )' $RESULT

    if [ "$(yq .resources.$KEY.hpa $CFG)" != "null" ]; then
      yq -i '.xano.k8s.deployments.'$KEY'.hpa = ({"enabled":true,"name":"'$KEY'"} + (load("'$CFG'").resources.'$KEY'.hpa))' $RESULT
    else
      yq -i '.xano.k8s.deployments.'$KEY'.hpa = ({"enabled":false,"name":"'$KEY'"})' $RESULT
    fi
  done

  yq -i '.xano *= load("'$LIC'")' $RESULT
}

fetch_license() {
  LICID=$1

  LIC=$(curl "$XANO_ORIGIN/api:license/license/$LICID" 2>/dev/null)
  NAME=$(echo "$LIC" | yq .license.name 2>/dev/null)

  if [ "$NAME" = "" ] || [ "$NAME" = "null" ]; then
    echo "Unable to locate license."
    exit 1
  fi

  FILE="./${NAME}-license.yaml"

  echo "$LIC" > $FILE

  echo "license saved: $FILE"
}

package_with_license() {
  SRC=$1

  package $SRC

  RESULT=$(get_result_file $SRC)
  NAMESPACE=$(get_namespace $SRC)
  LICENSE=$(get_license $SRC)

  RELEASE=$(get_release $SRC)
  if [ "$RELEASE" = "" ]; then
    echo "Missing release."
    exit 1
  fi

  ORIGIN=$(get_origin $SRC)
  if [ "$ORIGIN" = "" ]; then
    echo "Missing origin."
    exit 1
  fi

  LICDATA=$(curl -G "${ORIGIN}/api:master/license/${LICENSE}" -d "release_id=${RELEASE}" 2>/dev/null)

  MESSAGE=$(echo "$LICDATA" | yq -p json .message)
  if [ "$MESSAGE" != "null" ]; then
    echo "ERROR: $MESSAGE"
    exit 1
  fi

  XANO_ID=$(echo "$LICDATA" | yq .xano.id)
  if [ "$XANO_ID" = "null" ]; then
    echo "ERROR - Unable to retrieve license"
    exit 1
  fi

  IMAGES=$(echo "$LICDATA" | yq .extras.images)

  yq -i ". *= $LICDATA" $RESULT
  yq -i "del(.extras)" $RESULT
}

deploy_with_license() {
  SRC=$1

  CHART=$(yq .xano.k8s.images.helm.name $SRC)
  VERSION=$(yq .xano.k8s.images.helm.tag $SRC)
  NAMESPACE=$(yq .xano.k8s.namespace.name $SRC)

  helm upgrade -i $HELM_RELEASE $CHART --version $VERSION --namespace $NAMESPACE --create-namespace --values $SRC
}


while :; do
  case $1 in
  "")
    break
    ;;
  package)
    shift

    LIC=$(get_arg -lic "$@")
    validate_license "$LIC"

    CFG=$(get_arg -cfg "$@")
    validate_config "$CFG"

    package "$LIC" "$CFG"

    echo "done"
    exit
    ;;
  deploy)
    shift

    LIC=$(get_arg -lic "$@")
    validate_license "$LIC"

    CFG=$(get_arg -cfg "$@")
    validate_config "$CFG"

    package "$LIC" "$CFG"

    RESULT=$(get_result_file $LIC)

    deploy_with_license $RESULT

    echo "done"
    exit
    ;;
  list-users)
    shift

    CFG=$(get_arg -cfg "$@")
    validate_config "$CFG"

    NAMESPACE=$(get_namespace $CFG)

    kubectl exec deploy/backend -n $NAMESPACE -- php /xano/bin/tools/helm/list-users.php

    exit
    ;;
  get-user)
    shift

    CFG=$(get_arg -cfg "$@")
    validate_config "$CFG"

    BY=$(get_arg -by "$@")

    FIELD=id
    NAMESPACE=$(get_namespace $CFG)

    if [[ $BY == *"@"* ]]; then
      FIELD=email
    fi

    kubectl exec deploy/backend -n $NAMESPACE -- php /xano/bin/tools/helm/get-user.php --$FIELD $BY

    exit
    ;;
  del-user)
    shift

    CFG=$(get_arg -cfg "$@")
    validate_config "$CFG"

    BY=$(get_arg -by "$@")

    FIELD=id
    NAMESPACE=$(get_namespace $CFG)

    if [[ $BY == *"@"* ]]; then
      FIELD=email
    fi

    kubectl exec deploy/backend -n $NAMESPACE -- php /xano/bin/tools/helm/del-user.php --$FIELD $BY

    exit
    ;;
  add-user)
    shift

    CFG=$(get_arg -cfg "$@")
    validate_config "$CFG"

    NAME=$(get_arg -name "$@")
    EMAIL=$(get_arg -email "$@")
    PASS=$(get_arg -pass "$@")

    NAMESPACE=$(get_namespace $CFG)

    kubectl exec deploy/backend -n $NAMESPACE -- php /xano/bin/tools/helm/add-user.php --name "$NAME" --email "$EMAIL" --password "$PASS"

    exit
    ;;
  set-user-pass)
    shift

    CFG=$(get_arg -cfg "$@")
    validate_config "$CFG"

    BY=$(get_arg -by "$@")
    PASS=$(get_arg -pass "$@")

    FIELD=id
    NAMESPACE=$(get_namespace $CFG)

    if [[ $BY == *"@"* ]]; then
      FIELD=email
    fi

    kubectl exec deploy/backend -n $NAMESPACE -- php /xano/bin/tools/helm/set-user-pass.php --$FIELD $BY --password $PASS

    exit
    ;;
  public-releases)
    RELEASES=$(curl "$XANO_ORIGIN/api:license/public/releases" 2>/dev/null)

    echo "$RELEASES" | yq -P -o json '.items'
    exit
    ;;
  beta-releases)
    RELEASES=$(curl "$XANO_ORIGIN/api:license/beta/releases" 2>/dev/null)

    echo "$RELEASES" | yq -P -o json '.items'
    exit
    ;;
  get-license)
    shift

    LICID=$(get_arg -key "$@")

    if [[ ! $LICID =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]]; then
      echo "Please enter a valid license id."
      exit
    fi

    fetch_license "$LICID"
    exit
    ;;
  set-license-release)
    shift

    LICID=$(get_arg -key "$@")

    if [[ ! $LICID =~ ^\{?[A-F0-9a-f]{8}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{4}-[A-F0-9a-f]{12}\}?$ ]]; then
      echo "Please enter a valid license id."
      exit
    fi

    RELEASEID=$(get_arg -release "$@")

    LIC=$(curl -X PUT "$XANO_ORIGIN/api:license/license/$LICID/release/$RELEASEID" 2>/dev/null)
    MESSAGE=$(echo "$LIC" | yq -p json .message)
    if [ "$MESSAGE" != "null" ]; then
      echo "ERROR: $MESSAGE"
      exit 1
    fi

    fetch_license "$LICID"
    exit
    ;;
  install-cluster-issuer)
    shift

    LIC=$(get_arg -lic "$@")
    validate_license "$LIC"

    LICID=$(get_license $LIC)
    EMAIL=$(get_email $LIC)

    CLUSTER_ISSUER_FILE=$(get_arg -file "$@")
    validate_file $CLUSTER_ISSUER_FILE

    DATA=$(get_file $CLUSTER_ISSUER_FILE)
    validate_clusterissuer "$DATA"

    DATA=$(echo "$DATA" | yq '.spec.acme.email = "'$EMAIL'"') # = "'$EMAIL'")
    echo "$DATA" | kubectl apply -f -

    exit
    ;;
  version)
    echo $VERSION
    exit
    ;;
  help)
    ACTION=$1
    ;;
  esac
  shift
done

case "$ACTION" in
help)
  echo "xano-helm.sh $VERSION - Xano Standation (Enterprise Edition) management"
  echo ""
  echo "Commands:"
  echo "  deploy: deploy enteprise instance"
  echo "    -lic: the license file"
  echo "    -cfg: the config file of your instance"
  echo "  package: create the package file for deployment (debuging only)"
  echo "    -lic: the license file"
  echo "    -cfg: the config file of your instance"
  echo "  list-users: display the instance users"
  echo "    -cfg: the config file of your instance"
  echo "  add-user: create a user"
  echo "    -cfg: the config file of your instance"
  echo "    -name: the name of the user"
  echo "    -email: the email of the user"
  echo "    -pass: the password of the user"
  echo "  get-user: display a single user from your instance"
  echo "    -cfg: the config file of your instance"
  echo "    -by: the id or email of the user"
  echo "  set-user-pass: set the user password"
  echo "    -cfg: the config file of your instance"
  echo "    -by: the id or email of the user"
  echo "    -pass: the new password of the user"
  echo "  del-user: delete a user from your instance"
  echo "    -cfg: the config file of your instance"
  echo "    -by: the id or email of the user"
  echo "  public-releases: display the recent public releases"
  echo "  beta-releases: display the recent beta releases"
  echo "  get-license: retrieve a current license file bundled with the latest public release"
  echo "    -id: the license id of your instance"
  echo "  renew-license: retrieve a current license file bundled with the latest public release"
  echo "    -lic: the file name of your license"
  echo "    -release: the release id to be bound to your license"
  echo "  version: display the version of this shell script"
  echo "  help"
  echo "     display this menu"
  echo ""
  exit
  ;;
esac

echo "done"
