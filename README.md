# guacamole-compose
## guac-PR
Configuration script and docker-compose YML for deploying Apache Guacamole (v1.3.0) + Traefik + PostgreSQL.

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


## Running

```bash
chmod +x init.sh
./init.sh

docker-compose -f /etc/guacamole/guac-PR/docker-compose.yml up -d
```
