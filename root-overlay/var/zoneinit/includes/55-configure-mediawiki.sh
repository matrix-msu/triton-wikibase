#!/usr/bin/bash

PASSWORD=`/usr/bin/uuid`
echo -n $PASSWORD | /usr/sbin/mdata-put mysql-password 

MEDIAWIKIPW=`/usr/bin/uuid`
echo -n $MEDIAWIKIPW | /usr/sbin/mdata-put mediawiki-password 

SITEURL=http://`mdata-get sdc:alias`.`mdata-get sdc:dns_domain`


/opt/local/bin/mysql -u root <<-EOF
UPDATE mysql.user SET authentication_string=PASSWORD('$PASSWORD') WHERE User='root';
FLUSH PRIVILEGES;
EOF

cd /opt/local/share/httpd/htdocs/w/maintenance

php install.php \
	--installdbuser root --installdbpass `mdata-get mysql-password` \
	--dbserver localhost --dbtype mysql \
	--dbuser mediawiki --dbpass `mdata-get mediawiki-password` \
	--pass `mdata-get mediawiki-password` \
        --server $SITEURL \
	WIKINAME WIKIROOT 

#Now we enable wikibase the software was deployed as part of the
#image, but final configuration and enabling must happen post
#mediawiki setup

cat >> /opt/local/share/httpd/htdocs/w/LocalSettings.php <<-EOF
\$wgEnableWikibaseRepo = true;
\$wgEnableWikibaseClient = true;
require_once "\$IP/extensions/Wikibase/repo/Wikibase.php";
require_once "\$IP/extensions/Wikibase/repo/ExampleSettings.php";
require_once "\$IP/extensions/Wikibase/client/WikibaseClient.php";
require_once "\$IP/extensions/Wikibase/client/ExampleSettings.php";
EOF

cat >> /opt/local/share/httpd/htdocs/w/LocalSettings.php <<-EOF

wfLoadExtension( 'OAuth' );
\$wgMainCacheType = CACHE_ACCEL; ## because oauth uses cache as tmp

\$wgGroupPermissions['sysop']['mwoauthproposeconsumer'] = true;
\$wgGroupPermissions['sysop']['mwoauthupdateownconsumer'] = true;
\$wgGroupPermissions['sysop']['mwoauthmanageconsumer'] = true;
\$wgGroupPermissions['sysop']['mwoauthsuppress'] = true;
\$wgGroupPermissions['sysop']['mwoauthviewsuppressed'] = true;
\$wgGroupPermissions['sysop']['mwoauthviewprivate'] = true;
\$wgGroupPermissions['sysop']['mwoauthmanagemygrants'] = true;

\$wgGroupPermissions['sysop']['userrights'] = true;

EOF


cat >> /opt/local/share/httpd/htdocs/w/LocalSettings.php <<-EOF
\$wgScriptPath = "/w";
\$wgArticlePath = "/wiki/\$1";

EOF


cd /opt/local/share/httpd/htdocs/w/
php maintenance/update.php
cd extensions/Wikibase/
php lib/maintenance/populateSitesTable.php




