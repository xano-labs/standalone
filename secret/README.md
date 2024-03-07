# Variable Configs

The `secret` directory can be used to store environment files.

These files will be ignored by git, so you can safely add files here and not worry about them getting checked into the repository.

You can clone the placeholder.vars file, give it a new name, and then update it with your own settings.

You can then run those settings, using the following command.

```shell
# rename placeholder.conf to whatever file you want
./xano.sh -vars ./secret/placeholder.vars
```
