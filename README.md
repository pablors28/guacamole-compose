# guacamole-compose
Docker compose files and build script for Apache Guacamole (v1.3.0) + Traefik + PostgreSQL.

It allows to quickly deploy a jumpserver solution using Apache Guacamole that supports local authentication, LDAP and TOTP (2FA)

If you are running on a linux OS, you can run the **init.sh** file to magically create the directory structure and the files needed for the deployment to work

## Usage: init.sh
### Define variables
**basePath** --> Path where the solution will run. Here's where the database, config and recordings are stored.

**guacDomain** --> DNS name of guacamole (common name of the certificate)

**userDB** --> Database user

**passDB** --> Password of *userDB*

**DBname** --> Guacamole database name

**LDAPDomain** --> If using LDAP auth... the LDAP Domain

**LDAPUserDN** --> DN of where are the users located

**LDAPFilter** --> LDAP filter to allow users to connect

**LDAPBind** --> LDAP user to bind to the server

**LDAPBindPass** --> Password of the user defined in *LDAPBind*

#### Example:
```bash
# DEFINE VARIABLES
__basePath="/etc/guacamole/guac-PR"
__guacDomain="guacamole.local"
__userDB="guacamole_user"
__passDB="U5er.D8-pa5sW0rd"
__DBname="guacamole_db"
__LDAPDomain="localdomain"
__LDAPUserDN="OU=Users,DC=localdomain"
__LDAPFilter="(|(memberOf=CN=Guacamole Admins,DC=localdomain)(memberOf=CN=Guacamole Users,DC=localdomain))"
__LDAPBind="CN=guacuser,OU=Users,DC=localdomain"
__LDAPBindPass="gu4c9ASs"
```

### TLS Certificates
When you run ***init.sh*** it generates a self signed certificate to be able to use https.
```bash
openssl req -nodes -newkey rsa:4096 -new -x509 -keyout $__basePath/ssl/jumpserver.key -out $__basePath/ssl/jumpserver.cer -subj "/CN=$__guacDomain" -days 398
```

If you wish, you can use your own certificates by placing the private key on ***basePath*/ssl/jumpserver.key** and the certificate on ***basePath*/ssl/jumpserver.cer**

### ENABLE LDAP AUTH
Uncomment lines 74-81 on ***docker-compose.yml*** located on the path configured on *basePath*

```
[...]
#### UNCOMMENT TO ENABLE LDAP AUTH  ####    
#LDAP_HOSTNAME: localdomain
#LDAP_PORT: 389
#LDAP_ENCRYPTION_METHOD: none
#LDAP_USER_BASE_DN: OU=Users,DC=localdomain
#LDAP_USERNAME_ATTRIBUTE: sAMAccountName
#LDAP_SEARCH_BIND_DN: CN=guacuser,OU=Users,DC=localdomain
#LDAP_SEARCH_BIND_PASSWORD: gu4c9ASs
#LDAP_USER_SEARCH_FILTER: (|(memberOf=CN=Guacamole Admins,DC=localdomain)(memberOf=CN=Guacamole Users,DC=localdomain))
#####  #####  ####  
[...]
```

### TOTP (2FA) RESET
1. Run ***docker ps*** to get the container ID of the PostgreSQL service
```
$ sudo docker ps
[...]
1820d1e2526f   postgres:13                 "docker-entrypoint.s…"   [...]
[...]
```

2. With the container ID execute the psql CLI
```
$ sudo docker exec -it 1820d1e2526f psql -U guacamole_user guacamole_db
psql (13.3 (Debian 13.3-1.pgdg100+1))
Type "help" for help.

guacamole_db=#
```

3. Obtain the ***user_id*** you wish to reset the TOTP:
```
guacamole_db=# SELECT user_id FROM guacamole_user INNER JOIN guacamole_entity ON guacamole_entity.entity_id = guacamole_user.entity_id WHERE guacamole_entity.name = 'guacadmin';
 user_id
---------
       1
(1 row)
```

4. Update the DB value to reset the TOTP:
```
guacamole_db=# UPDATE guacamole_user_attribute SET attribute_value='false' WHERE attribute_name = 'guac-totp-key-confirmed' and user_id = '1';
UPDATE 1
guacamole_db=# quit
```

5. Rescan the QR code ;)

## Running

```bash
chmod +x init.sh
$ sudo ./init.sh

$ sudo docker-compose -f /etc/guacamole/guac-PR/docker-compose.yml up -d
```

## Login
Default username and password

**user**: *guacadmin*

**pass**: *guacadmin*
