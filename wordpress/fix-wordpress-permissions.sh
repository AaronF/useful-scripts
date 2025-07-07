#!/bin/bash
#
# http://codex.wordpress.org/Hardening_WordPress#File_permissions
#
# Make sure the FTP user is in the www-data group
# e.g. sudo usermod -a -G www-data your_user_name
#
WP_OWNER=www-data # <-- wordpress owner
WP_GROUP=www-data # <-- wordpress group
WP_ROOT=$1 # <-- wordpress root directory
WS_GROUP=www-data # <-- webserver group

echo "Working..."

# reset to safe defaults
find ${WP_ROOT} -exec chown ${WP_OWNER}:${WP_GROUP} {} \;
find ${WP_ROOT} -type d -exec chmod 755 {} \;
find ${WP_ROOT} -type f -exec chmod 644 {} \;

# setup folder ownership
chmod 775 ${WP_ROOT}
chmod g+s ${WP_ROOT}
chmod g+s -R ${WP_ROOT}/wp-content

# allow wordpress to manage wp-config.php (but prevent world access)
chgrp ${WS_GROUP} ${WP_ROOT}/wp-config.php
chmod 660 ${WP_ROOT}/wp-config.php

# allow wordpress to manage wp-content
find ${WP_ROOT}/wp-content -exec chgrp ${WS_GROUP} {} \;
find ${WP_ROOT}/wp-content -type d -exec chmod 775 {} \;
find ${WP_ROOT}/wp-content -type f -exec chmod 664 {} \;

if [ ! -d ${WP_ROOT}/wp-content/cache ]; then
	mkdir -p ${WP_ROOT}/wp-content/cache;
fi
find ${WP_ROOT}/wp-content/cache -type d -exec chmod 755 {} \;

echo "Done"