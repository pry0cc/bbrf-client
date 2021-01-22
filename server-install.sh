#!/bin/bash

echo "
        /|        /|                          
        ||        ||                     _.._ 
        ||        ||        .-,.--.    .' .._|
        ||  __    ||  __    |  .-. |   | '    
        ||/'__ '. ||/'__ '. | |  | | __| |__  
        |:/   '. '|:/   '. '| |  | ||__   __| 
        ||     | |||     | || |  '-    | |    
        ||\    / '||\    / '| |        | |    
        |/\'..' / |/\'..' / | |        | |    
        '   '-'   '   '-'   |_|        | |    
                                       |_|    
                                       
\"I added some ASCII art because you can't have a bash script without ASCII art\"  - @plenumlab								   
"

sudo curl -L "https://github.com/docker/compose/releases/download/1.28.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

curl -sSL https://raw.githubusercontent.com/bitnami/bitnami-docker-couchdb/master/docker-compose.yml > docker-compose.yml
echo "Replacing default password and removing ports 9100,4369"
adminpass=$(openssl rand -base64 32)
										
if [[ "$OSTYPE" == "darwin"* ]]; then MACOS="''"; fi
sed -i $MACOS "s|=couchdb|=$adminpass|g" docker-compose.yml
sed -i $MACOS "s|- '4369:4369'||g" docker-compose.yml
sed -i $MACOS "s|- '9100:9100'||g" docker-compose.yml
echo "Your administrator username is admin"
echo "Your administrator password is $adminpass"
docker-compose up -d
sleep 20


admin="admin"
passwd="$adminpass"
url="http://$(curl -s ifconfig.me):5984"

echo "Creating BBRF database..."  
curl -u $admin:$passwd -X PUT $url/bbrf 
user="pry"
upass=$(openssl rand -base64 32) && echo "Password for low-privilege user is: $upass"

echo "Creating the low-privilege user..."
curl -u $admin:$passwd -X PUT $url/_users/org.couchdb.user:$user \
     -H "Accept: application/json" \
     -H "Content-Type: application/json" \
     -d "{\"name\": \"$user\", \"password\": \"$upass\", \"roles\": [], \"type\": \"user\"}"

echo "Configuring access rights to the BBRF database..."
curl -u $admin:$passwd -X PUT $url/bbrf/_security -d "{\"admins\": {\"names\": [\"$user\"],\"roles\": []}}"

echo "Creating required views..."
curl -u $user:$upass -X PUT $url/bbrf/_design/bbrf -d @views.json

echo -e "\nCreate a (default) config file under ~/.bbrf/config.json :\n"
echo -e "{\n\"username\": \"$user\",\n \"password\": \"$upass\",\n\"couchdb\": \"$url/bbrf\",\n \"slack_token\": \"$slack\"\n}" 

echo "Server setup completed..."
