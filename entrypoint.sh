#!/bin/bash
set -e

if [ -z "$MYSQL_PORT_3306_TCP_ADDR" ]; then
	echo >&2 'error: missing MYSQL_PORT_3306_TCP environment variable'
	echo >&2 '  Did you forget to --link some_mysql_container:mysql ?'
	exit 1
fi

# if we're linked to MySQL, and we're using the root user, and our linked
# container has a default "root" password set up and passed through... :)
: ${ETHERPAD_DB_USER:=root}
if [ "$ETHERPAD_DB_USER" = 'root' ]; then
	: ${ETHERPAD_DB_PASSWORD:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}
fi
: ${ETHERPAD_DB_NAME:=etherpad}

ETHERPAD_DB_NAME=$( echo $ETHERPAD_DB_NAME | sed 's/\./_/g' )

if [ -z "$ETHERPAD_DB_PASSWORD" ]; then
	echo >&2 'error: missing required ETHERPAD_DB_PASSWORD environment variable'
	echo >&2 '  Did you forget to -e ETHERPAD_DB_PASSWORD=... ?'
	echo >&2
	echo >&2 '  (Also of interest might be ETHERPAD_DB_USER and ETHERPAD_DB_NAME.)'
	exit 1
fi

: ${ETHERPAD_TITLE:=Etherpad}
: ${ETHERPAD_PORT:=9001}
: ${ETHERPAD_SESSION_KEY:=$(
		node -p "require('crypto').randomBytes(32).toString('hex')")}

# Check if database already exists
# RESULT=`mysql -u${ETHERPAD_DB_USER} -p${ETHERPAD_DB_PASSWORD} \
# 	-hmysql --skip-column-names \
# 	-e "SHOW DATABASES LIKE '${ETHERPAD_DB_NAME}'"`
# 
# if [ "$RESULT" != $ETHERPAD_DB_NAME ]; then
# 	# mysql database does not exist, create it
# 	echo "Creating database ${ETHERPAD_DB_NAME}"
# 
# 	mysql -u${ETHERPAD_DB_USER} -p${ETHERPAD_DB_PASSWORD} -hmysql \
# 	      -e "create database ${ETHERPAD_DB_NAME}"
# fi
echo npm install ep_hash_auth

if [ ! -f settings.json ]; then

	cat <<- EOF > settings.json
	{
	  "title": "${ETHERPAD_TITLE}",
	  "ip": "0.0.0.0",
	  "port" :${ETHERPAD_PORT},
	  "sessionKey" : "${ETHERPAD_SESSION_KEY}",
	  "dbType" : "mysql",
	  "dbSettings" : {
			    "user"    : "${ETHERPAD_DB_USER}",
			    "host"    : "mysql",
			    "password": "${ETHERPAD_DB_PASSWORD}",
			    "database": "${ETHERPAD_DB_NAME}"
			  },
	EOF
	
	
	if [ $ETHERPAD_PLUGINS ]; then
		for plugin in $(echo "${ETHERPAD_PLUGINS//,/
}"); do
			[ -d node_modules/$plugin ] || echo npm install $plugin

			VARNAME=$(echo $plugin | tr '[[:lower:]]' '[[:upper:]]')
			VARNAME="${VARNAME}_CONFIG"

			eval plugin_config=\$$VARNAME

			if [ $plugin_config ]; then
				echo "  $plugin_config," >> settings.json
			fi
			
		done
	fi


	if [ $ETHERPAD_ADMIN_ACCOUNTS ]; then
			cat <<- EOF >> settings.json
			  "users": {
			EOF

			for account in $(echo "${ETHERPAD_ADMIN_ACCOUNTS//:/
}"); do

				IFS='=' read user pass admin <<<$(echo "$account")
				echo "ACCT = $account"
				echo "U/P = $user : $pass : $admin"
				hashedpass=$(echo -n "$pass" | sha512sum | cut -d' ' -f1)

				admin=${admin:-false}

				echo "final admin = $admin"

				cat <<- EOF >> settings.json
				    "$user": {
				      "hash": "$hashedpass",
				      "is_admin": $admin
				    },
				EOF
			done
			echo "  }," >> settings.json
	
	elif [ $ETHERPAD_ADMIN_PASSWORD ]; then
		: ${ETHERPAD_ADMIN_HASHEDPASSWORD:=$(
			echo -n "$ETHERPAD_ADMIN_PASSWORD" | sha512sum | cut -d' ' -f1
		)}

		: ${ETHERPAD_ADMIN_USER:=admin}

		cat <<- EOF >> settings.json
		  "ep_hash_auth": { "hash_typ": "sha512", "hash_dig": "hex" },
		  "users": {
		    "${ETHERPAD_ADMIN_USER}": {
		      "hash": "${ETHERPAD_ADMIN_HASHEDPASSWORD}",
		      "is_admin": true
		    }
		  },
		EOF
	fi

	cat <<- EOF >> settings.json
	}
	EOF
fi

exec "$@"
