#!/usr/bin/bash

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


__traefikFile="tls:
  stores:
    default:
      defaultCertificate:
        certFile: /config/ssl/jumpserver.cer
        keyFile: /config/ssl/jumpserver.key
"


#CREATE DIRECTORIES AND PERMISSIONS
mkdir -p $__basePath/data
mkdir -p $__basePath/drive
mkdir -p $__basePath/record
mkdir -p $__basePath/share
mkdir -p $__basePath/init
mkdir -p $__basePath/tomcatConfig
mkdir -p $__basePath/guac_home/extensions
mkdir -p $__basePath/ssl
echo "DIRECTORIES CREATED..."
chmod 666 $__basePath/record
chmod 666 $__basePath/share
echo "PERMISSIONS GRANTED..."

echo "CREATING SSL CERTIFICATES (self signed)..."
openssl req -nodes -newkey rsa:4096 -new -x509 -keyout $__basePath/ssl/jumpserver.key -out $__basePath/ssl/jumpserver.cer -subj "/CN=$__guacDomain" -days 398 > /dev/null 2>&1


# COPY THE TOTP EXTENSION FROM THE CONTAINER
# COMMENT THE FOLLOWING LINES TO DISABLE TOTP
echo "COPYING TOTP EXTENSION"
__contID=$(docker create guacamole/guacamole:1.3.0)
echo "Container ID: $__contID"
docker cp $__contID:/opt/guacamole/totp/guacamole-auth-totp-1.3.0.jar $__basePath/guac_home/extensions/guacamole-auth-totp-1.3.0.jar
echo "DONE: $__basePath/guac_home/extensions/guacamole-auth-totp-1.3.0.jar"
docker rm $__contID
echo "DONE: Container deleted"

# WRITE TRAEFIK SSL CONFIG
echo "Writing Traefik SSL/TLS Configuration"
echo "$__traefikFile" > $__basePath/traefik.yml

# CREATE INIT DB SCRIPT
echo "Writing initdb.sql"
docker run --rm guacamole/guacamole:1.3.0 /opt/guacamole/bin/initdb.sh --postgres > $__basePath/init/initdb.sql
chmod +x $__basePath/init


# XML TOMCAT CONFIG... contains X-FORWADED config that shows the client real IP Address
echo "WRITING server.xml CONFIG FILE"
tee $__basePath/tomcatConfig/server.xml <<EOF123 > /dev/null
<?xml version="1.0" encoding="UTF-8"?>
<!--
  Licensed to the Apache Software Foundation (ASF) under one or more
  contributor license agreements.  See the NOTICE file distributed with
  this work for additional information regarding copyright ownership.
  The ASF licenses this file to You under the Apache License, Version 2.0
  (the "License"); you may not use this file except in compliance with
  the License.  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
-->
<!-- Note:  A "Server" is not itself a "Container", so you may not
     define subcomponents such as "Valves" at this level.
     Documentation at /docs/config/server.html
 -->
<Server port="8005" shutdown="SHUTDOWN">
  <Listener className="org.apache.catalina.startup.VersionLoggerListener" />
  <!-- Security listener. Documentation at /docs/config/listeners.html
  <Listener className="org.apache.catalina.security.SecurityListener" />
  -->
  <!--APR library loader. Documentation at /docs/apr.html -->
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
  <!-- Prevent memory leaks due to use of particular java/javax APIs-->
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />

  <!-- Global JNDI resources
       Documentation at /docs/jndi-resources-howto.html
  -->
  <GlobalNamingResources>
    <!-- Editable user database that can also be used by
         UserDatabaseRealm to authenticate users
    -->
    <Resource name="UserDatabase" auth="Container"
              type="org.apache.catalina.UserDatabase"
              description="User database that can be updated and saved"
              factory="org.apache.catalina.users.MemoryUserDatabaseFactory"
              pathname="conf/tomcat-users.xml" />
  </GlobalNamingResources>

  <!-- A "Service" is a collection of one or more "Connectors" that share
       a single "Container" Note:  A "Service" is not itself a "Container",
       so you may not define subcomponents such as "Valves" at this level.
       Documentation at /docs/config/service.html
   -->
  <Service name="Catalina">

    <!--The connectors can use a shared executor, you can define one or more named thread pools-->
    <!--
    <Executor name="tomcatThreadPool" namePrefix="catalina-exec-"
        maxThreads="150" minSpareThreads="4"/>
    -->


    <!-- A "Connector" represents an endpoint by which requests are received
         and responses are returned. Documentation at :
         Java HTTP Connector: /docs/config/http.html
         Java AJP  Connector: /docs/config/ajp.html
         APR (HTTP/AJP) Connector: /docs/apr.html
         Define a non-SSL/TLS HTTP/1.1 Connector on port 8080
    -->
    <Connector port="8080" protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="8443" />
    <!-- A "Connector" using the shared thread pool-->
    <!--
    <Connector executor="tomcatThreadPool"
               port="8080" protocol="HTTP/1.1"
               connectionTimeout="20000"
               redirectPort="8443" />
    -->
    <!-- Define an SSL/TLS HTTP/1.1 Connector on port 8443
         This connector uses the NIO implementation. The default
         SSLImplementation will depend on the presence of the APR/native
         library and the useOpenSSL attribute of the
         AprLifecycleListener.
         Either JSSE or OpenSSL style configuration may be used regardless of
         the SSLImplementation selected. JSSE style configuration is used below.
    -->
    <!--
    <Connector port="8443" protocol="org.apache.coyote.http11.Http11NioProtocol"
               maxThreads="150" SSLEnabled="true">
        <SSLHostConfig>
            <Certificate certificateKeystoreFile="conf/localhost-rsa.jks"
                         type="RSA" />
        </SSLHostConfig>
    </Connector>
    -->
    <!-- Define an SSL/TLS HTTP/1.1 Connector on port 8443 with HTTP/2
         This connector uses the APR/native implementation which always uses
         OpenSSL for TLS.
         Either JSSE or OpenSSL style configuration may be used. OpenSSL style
         configuration is used below.
    -->
    <!--
    <Connector port="8443" protocol="org.apache.coyote.http11.Http11AprProtocol"
               maxThreads="150" SSLEnabled="true" >
        <UpgradeProtocol className="org.apache.coyote.http2.Http2Protocol" />
        <SSLHostConfig>
            <Certificate certificateKeyFile="conf/localhost-rsa-key.pem"
                         certificateFile="conf/localhost-rsa-cert.pem"
                         certificateChainFile="conf/localhost-rsa-chain.pem"
                         type="RSA" />
        </SSLHostConfig>
    </Connector>
    -->

    <!-- Define an AJP 1.3 Connector on port 8009 -->
    <!--
    <Connector protocol="AJP/1.3"
               address="::1"
               port="8009"
               redirectPort="8443" />
    -->

    <!-- An Engine represents the entry point (within Catalina) that processes
         every request.  The Engine implementation for Tomcat stand alone
         analyzes the HTTP headers included with the request, and passes them
         on to the appropriate Host (virtual host).
         Documentation at /docs/config/engine.html -->

    <!-- You should set jvmRoute to support load-balancing via AJP ie :
    <Engine name="Catalina" defaultHost="localhost" jvmRoute="jvm1">
    -->
    <Engine name="Catalina" defaultHost="localhost">

      <!--For clustering, please take a look at documentation at:
          /docs/cluster-howto.html  (simple how to)
          /docs/config/cluster.html (reference documentation) -->
      <!--
      <Cluster className="org.apache.catalina.ha.tcp.SimpleTcpCluster"/>
      -->

      <!-- Use the LockOutRealm to prevent attempts to guess user passwords
           via a brute-force attack -->
      <Realm className="org.apache.catalina.realm.LockOutRealm">
        <!-- This Realm uses the UserDatabase configured in the global JNDI
             resources under the key "UserDatabase".  Any edits
             that are performed against this UserDatabase are immediately
             available for use by the Realm.  -->
        <Realm className="org.apache.catalina.realm.UserDatabaseRealm"
               resourceName="UserDatabase"/>
      </Realm>

      <Host name="localhost"  appBase="webapps"
            unpackWARs="true" autoDeploy="true">

        <!-- SingleSignOn valve, share authentication between web applications
             Documentation at: /docs/config/valve.html -->
        <!--
        <Valve className="org.apache.catalina.authenticator.SingleSignOn" />
        -->

        <!-- Access log processes all example.
             Documentation at: /docs/config/valve.html
             Note: The pattern used is equivalent to using pattern="common" -->
        <Valve className="org.apache.catalina.valves.AccessLogValve" directory="logs"
               prefix="localhost_access_log" suffix=".txt"
               pattern="%h %l %u %t &quot;%r&quot; %s %b" />

	<Valve className="org.apache.catalina.valves.RemoteIpValve"
               remoteIpHeader="x-forwarded-for"
               remoteIpProxiesHeader="x-forwarded-by"
               protocolHeader="x-forwarded-proto" />

      </Host>
    </Engine>
  </Service>
</Server>

EOF123



# YML COMPOSE
echo "WRITING COMPOSE file docker-compose.yml"
tee $__basePath/docker-compose.yml <<EOF123 > /dev/null

####################################################################################
# 20210706 - v1.5 - Pablo Rico
# Deployment Apache Guacamole+Traefik (Docker-Compose)
####################################################################################

####################################################################################
# TOTP RESET
####################################################################################
# docker exec -it <id contenedor> psql -U ${__userDB} ${__DBname}
# To obtain the user_id run:
# SELECT user_id FROM ${__userDB} INNER JOIN guacamole_entity ON guacamole_entity.entity_id = ${__userDB}.entity_id WHERE guacamole_entity.name = 'USUARIO';
# Update the user_id to reset the TOTP
# UPDATE ${__userDB}_attribute SET attribute_value='false' WHERE attribute_name = 'guac-totp-key-confirmed' and user_id = '1';
# quit
####################################################################################

version: '3.3'

# networks
networks:
  guacnetwork:
    driver: bridge


# services
services:
  # guacd
  guacd:
    container_name: guacd
    image: guacamole/guacd:1.3.0
    restart: always
    volumes:
    - $__basePath/drive:/drive:rw
    - $__basePath/record:/record:rw
    - $__basePath/share:/share:rw
    networks:
      - guacnetwork
  
  
  # postgres
  postgres:
    image: postgres:13
    container_name: postgres_DB
    environment:
      PGDATA: /var/lib/postgresql/data/guacamole
      POSTGRES_DB: ${__DBname}
      POSTGRES_PASSWORD: ${__passDB}
      POSTGRES_USER: ${__userDB}
    networks:
      - guacnetwork
    restart: always
    volumes:
      - $__basePath/init:/docker-entrypoint-initdb.d:ro
      - $__basePath/data:/var/lib/postgresql/data:rw
  
  # guacamole
  guacamole:
    container_name: guacamole
    image: guacamole/guacamole:1.3.0
    depends_on:
      - guacd
      - postgres
    environment:
      GUACAMOLE_HOME: /config
      GUACD_HOSTNAME: guacd
      POSTGRES_DATABASE: ${__DBname}
      POSTGRES_HOSTNAME: postgres
      POSTGRES_PASSWORD: ${__passDB}
      POSTGRES_USER: ${__userDB}
      POSTGRES_USER_REQUIRED: 'true'
      #### UNCOMMENT TO ENABLE LDAP AUTH  ####    
      #LDAP_HOSTNAME: ${__LDAPDomain}
      #LDAP_PORT: 389
      #LDAP_ENCRYPTION_METHOD: none
      #LDAP_USER_BASE_DN: ${__LDAPUserDN}
      #LDAP_USERNAME_ATTRIBUTE: sAMAccountName
      #LDAP_SEARCH_BIND_DN: ${__LDAPBind}
      #LDAP_SEARCH_BIND_PASSWORD: ${__LDAPBindPass}
      #LDAP_USER_SEARCH_FILTER: ${__LDAPFilter}
      #####  #####  ####  

    links:
      - guacd
    networks:
      - guacnetwork
    ports:
      - 8080/tcp
    restart: always 
    volumes:
      - $__basePath/guac_home:/config:rw
      - $__basePath/tomcatConfig/server.xml:/usr/local/tomcat/conf/server.xml:ro
    labels:
      - "traefik.enable=true"
      - "traefik.port=8080"
      #Enable Sticky Sessions (to allow load balancing in case of using more than one traefik instance)
      - "traefik.http.services.guacamole.loadbalancer.sticky.cookie=true"
      - "traefik.http.services.guacamole.loadbalancer.sticky.cookie.name=StickyGuac"
      - "traefik.http.routers.guacamole-http.rule=Host(\`${__guacDomain}\`)||PathPrefix(\`/\`)"
      - "traefik.http.routers.guacamole-http.entrypoints=http"
      - "traefik.http.routers.guacamole-https.rule=Host(\`${__guacDomain}\`)||PathPrefix(\`/\`)"
      - "traefik.http.routers.guacamole-https.entrypoints=https"
      - "traefik.http.routers.guacamole-https.tls=true"
      - "traefik.http.services.guacamole.loadbalancer.server.port=8080"
      - "traefik.http.routers.guacamole-http.middlewares=redirect"
      - "traefik.http.middlewares.redirect.redirectscheme.scheme=https"
      # the middleware 'add-context' must be defined so that the regex rules can be attached to it
      - "traefik.http.routers.guacamole-https.middlewares=add-context"
      # Redirect to /guacamole:
      - "traefik.http.middlewares.add-context.redirectregex.regex=^https:\\\\/\\\\/([^\\\\/]+)\\\\/?$\$"
      - "traefik.http.middlewares.add-context.redirectregex.replacement=https://$\$1/guacamole"

  loadbalancer:
    image: traefik:2.4
    container_name: traefik
    depends_on:
      - guacamole
    command:
      # Enable Docker in Traefik, so that it reads labels from Docker services
      - --providers.docker=true
      #- --providers.docker.watch=true
      - --providers.docker.network=guacamole_guacnetwork
      # Do not expose all Docker services, only the ones explicitly exposed
      - --providers.docker.exposedbydefault=false
      # Create an entrypoint "http" listening on address 80
      - --entrypoints.http.address=:80
      - --entryPoints.http.forwardedHeaders.insecure
      # Create an entrypoint "https" listening on address 443
      - --entrypoints.https.address=:443
      - --entryPoints.https.forwardedHeaders.insecure
      # Enable the access log, with HTTP requests
      - --accesslog
      # Enable the Traefik log, for configurations and errors
      - --log
      # --log.level=DEBUG
      # Enable the Dashboard and API
      - --api.insecure=true
      # TLS configuration
      - --providers.file.filename=/etc/traefik/dynamic_conf/conf.yml
    networks:
      - guacnetwork
    ports:
      - mode: host
        protocol: tcp
        published: 80
        target: 80
      - mode: host
        protocol: tcp
        published: 443
        target: 443
      - 8080:8080
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
     #Certificates path
      - $__basePath/ssl/:/config/ssl/:ro
     #Config path
      - $__basePath/traefik.yml:/etc/traefik/dynamic_conf/conf.yml:ro
    restart: always 
    labels:
        - traefik.enable=true
        - traefik.docker.network=guacamole_guacnetwork
EOF123



echo "FINISHED!"
echo "You can use your own certificates by placing the private key in $__basePath/ssl/jumpserver.key and the cert in $__basePath/ssl/jumpserver.cer"

echo "Run the following command:"
echo "docker-compose -f $__basePath/docker-compose.yml up -d"
