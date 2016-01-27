Etherpad image for docker
=========================

This image is based on tvelocity/etherpad.

Additionally, we are now sensitive to two additional (plus N) new environment variables.

Far from ideal (does not have salting in passwords) this image at least provides for self installable and configurable modules (exc. for login, which goes at "users" key in settings.json).

New keys provided:

$ETHERPAD_ADMIN_ACCOUNTS is a colon-separated list of equal-separated users and passwords (and optional admin capability).
Thus, an example of

ETHERPAD_ADMIN_ACCOUNTS=admin=secret=true:user=anybody=false:another=user

will create three users: admin/secret admin user; user/anybody non-admin and another/user non-admin.

The other variable, $ETHERPAD_PLUGINS is a space-separated list of plugins. For each installed plugin, if a variable by the name EP_XXXX_CONFIG (where EP_XXX is the uppercased name of the plugin) exists, it will be pasted onto settings.json (and appended a comma), so you would have just to say EP_X_CONFIG='"key":{"a":"b","c":d"}'.
