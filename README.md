# Xano Standalone 1.0.5

## What is Xano Standalone?

Xano Standalone is a self hosted version of Xano that is completely isolated to a single docker image. This makes it extremely portable for POC solutions, especially within an on-premise environment.

This version of Xano is not designed to be a scalable solution and has made many tradeoffs in term of flexibility of getting started with a POC. Once a POC is successful, it is common to upgrade this license into a scalable Enterprise solution, which can be setup within a cloud or on-premise environment. 

## TL;DR - I'm ready to get started

1. Get your standalone license from your account representive or contact sales@xano.com for more information
2. Clone this repository - `git clone git@gitlab.com:xano/standalone.git`
3. Rename the `placeholder.vars` file to your own file and update the variables inside based on your license - i.e. `custom.vars`
4. Startup the standalone instance with the following command: `./xano.sh -vars custom.vars`

## How do I get a license?

If you don't have a license, then please contact sales@xano.com for more information.

## Running Xano Standalone

This can be done by cloning this repository and running xano.sh.

```shell
git clone git@gitlab.com:xano/standalone.git
cd standalone

./xano.sh
```


or... it can be done on the fly using curl.

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
 -vars: a variable file
 -port: web port, default: 4200
    env: XANO_PORT
 -domain: the xano master domain, default: app.xano.com
    env: XANO_DOMAIN
 -tag: the docker image tag, default: latest
 -rmvol: remove the volume if it exists
 -nopull: skip pulling the latest docker image
 -incognito: skip creating a volume, so everything is cleared once the container exits
 -daemon: run in the background
 -shell: run a shell instead of normal entrypoint (this requires no active container)
 -connect: run a shell into the existing container
 -credentials: retrieve the initial credentials
 -ver: display the shell script version
 -help: display this menu
```

## Variable Config File

You can leverage the `-vars` parameter to reference multiple variables in a single command.

## Environment Variables

The prefered method of using variables is via the `-vars` parameter, but you can use individual environment variables as well if you prefer this method.

- export XANO_INSTANCE=CHANGE_ME
- export XANO_TOKEN=CHANGE_ME
- export XANO_DOMAIN=app.xano.com
- export XANO_PORT=4201

You can then validate that the environment variables have been setup properly using the following command:

```shell
printenv | grep XANO_
```
If you see something similiar to this below, then everything is setup properly.
```shell
XANO_INSTANCE=CHANGE_ME
XANO_TOKEN=CHANGE_ME
XANO_DOMAIN=app.xano.com
XANO_PORT=4200
```

# Frequently Asked Questions

## How do I create and use my own variables file?

There is a `placeholder.vars` file in this repository. Go ahead and rename it, then proceed to update the variables to make them relavent to your environment.

See the following series of commands as an example:

```shell
~/git/standalone$ mv placeholder.vars me.vars

# use an editor to edit me.vars

# run the shell script with this new file after you are done editing it 
~/git/standalone$ ./xano.sh -vars me.vars
```

## Does Xano Standalone require an internet connection?

It only requires an internet connection to fetch the initial docker image and acquire a license.

If a license has an expiration, it will not contact the license server again until the license is expired.

It is also important to specify the `-nopull` parameter, so as to not request the latest version of Xano Standalone. Otherwise, if using the "latest" tag, it will check to see if there is an update.

## Is there a way to run Xano Standalone in the background?

Yes. You can use the `-daemon` parameter to run it in the background.

## Is there a way to enter the container and view logs?

Yes. There are two methods you can use to explore the container.

If you want to explore the container without it currently running, then use the `-shell` parameter. This requires no active container running.

If you want to explore the container while it is running, then use the `-connect` parameter.

Commonly used directories would be the following:
  - `/tmp`
  - `/xano/storage/tmp`
  - `/xano/storage/postgresql`

## Is storage persistent?

Yes. A docker volume is created which allows the data to persist between running the standalone edition. 

If you want to use temporary storage, try using the `-incognito` parameter.

## Can I use temporary storage?

Yes. You can do this using the `-incognito` parameter.

This means that the storage is deleted as soon as the container ends.

## I would like to start over. Can I clear out my volume?

Yes. If you want to start with a fresh volume, then run the script with the `-rmvol` parameter.

## I started the daemon, but now I want to stop it. How do I do that?

Run the script with the `-stop` parameter. This will stop the daemon.

## I have Xano standalone running, but how do I login?

The initial credentials should have been emailed to the license owner. If you don't have them, you can reach out to your account representative.

You can also retrieve them with the `-credentials` parameter.

