#!/bin/bash

# Fetch JSON array of services
info=$(lando info --format=json)

# Extract the database service block
db_service=$(echo "$info" | jq -r '.[] | select(.service == "database")')

# Extract required fields
host=$(echo "$db_service" | jq -r '.external_connection.host')
port=$(echo "$db_service" | jq -r '.external_connection.port')
user=$(echo "$db_service" | jq -r '.creds.user')
pass=$(echo "$db_service" | jq -r '.creds.password')
db=$(echo "$db_service" | jq -r '.creds.database')

open "mysql://$user:$pass@$host:$port/$db"