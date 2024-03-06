# Xano Standalone

## What is Xano Standalone?

Xano Standalone is a self hosted version of Xano that is completely isolated to a single docker image. This makes it extremely portable for POC solutions, especially within an on-premise environment.

This version of Xano is not designed to be a scalable solution and has made many tradeoffs in term of flexibility of getting started with a POC. Once a POC is successful, it is common to upgrade this license into a scalable Enterprise solution, which can be setup within a cloud or on-premise environment. 

## How do I get a license?

If you don't have a license, then please contact sales@xano.com for more information.

## Running Xano Standalone

This can be done by downloading and running xano.sh, or it can be done on the fly using curl.

```shell
curl -s 'https://gitlab.com/xano/standalone/-/raw/main/xano.sh' | bash -s --
```

```
Xano Standalone Edition

Required parameters:
 -instance: xano instance name, e.g. x123-abcd-1234
    env: XANO_INSTANCE
 -token: your metadata api token - env: XANO_TOKEN
    env: XANO_TOKEN

Optional parameters:
 -port: web port, default: 4200
    env: XANO_PORT
 -domain: the xano master domain, default: app.xano.com
    env: XANO_DOMAIN
 -tag: the docker image tag, default: latest
 -nopull: skip pulling the latest docker image
 -incognito: skip creating a volume, so everything is cleared once the container exits
 -daemon: run in the background
 -shell: run a shell instead of normal entrypoint (this requires no active container)
 -connect: run a shell into the existing container
 -help: display this menu
```

## Environment Variables

The following environment variables are recommended to make it easier to use the Xano Standalone edition.

- export XANO_DOMAIN=app.xano.com
- export XANO_PORT=4200
- export XANO_INSTANCE=CHANGE_ME
- export XANO_TOKEN=CHANGE_ME

These variables are also located in env.sh which can be downloaded, customized, and then loaded into your environment via the following command.

```shell
source env.sh
```

You can then validate that the environment variables have been setup properly using the following command:

```shell
printenv | grep XANO_
```
If you see something similiar to this below, then everything is setup properly.
```shell
XANO_TOKEN=CHANGE_ME
XANO_PORT=4200
XANO_INSTANCE=CHANGE_ME
XANO_DOMAIN=app.xano.com
```

# Frequently Asked Questions

## Does Xano Standalone require an internet connection?

- It only requires an internet connection to fetch the initial docker image and acquire a license.
- If a license has an expiration, it will not contact the license server again until the license is expired.
- It is also important to specify the `-nopull` parameter, so as to not request the latest version of Xano Standalone. Otherwise, if using the "latest" tag, it will check to see if there is an update.

## Is there a way to run Xano Standalone in the background?

- Yes. You can use the `-daemon` parameter to run it in the background.

## Is there a way to enter the container and view logs?

- Yes. If you want to explore the container without it currently running, then use the `-shell` parameter. This requires no active container running.
- If you want to explore the container while it is running, then use the `-connect` parameter.
- Commonly used directories would be the following:
  - `/tmp`
  - `/xano/storage/tmp`
  - `/xano/storage/postgresql`