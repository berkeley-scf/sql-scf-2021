#!/bin/bash

## UNIX bash shell script illustrating use of postgres within a Docker container, for use if you do not have access to a Postgres database.

## A docker container is basically a Linux (virtual) machine running within your computer.

## Docker containers often come with only a minimal amount of software installed and you need to install the software you want. But you can start up containers that have some software pre-installed. In this particular example it was easiest to run a container with R already installed and then to add PostgreSQL to the container.

## If you follow the steps below you will be in a a Docker container in which you can create a PostgreSQL database, add data to the database and then access it from R, we do in the tutorial. 


## Run a container with R already installed, starting a bash shell terminal session in the container. Also forward port 5432 on the container to local port 63333 for later use.
docker run --rm -p 63333:5432 -ti  rocker/r-base /bin/bash

## install Postgres and SSH/SCP (the latter for copying files into the container)
apt-get update
apt-get install -y postgresql postgresql-contrib libpq-dev
apt-get install -y openssh-client

## If you want to be able to connect to postgres from outside the container, do these steps:
PG_VER=13  # modify as needed
echo -e "host\tall\t\tall\t\t0.0.0.0/0\t\tmd5" >> /etc/postgresql/${PG_VER}/main/pg_hba.conf
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/${PG_VER}/main/postgresql.conf

## start the postgres server process
/etc/init.d/postgresql start

## get the data into the container
mkdir /data
cd /data
wget https://www.stat.berkeley.edu/share/paciorek/tutorial-databases-data.zip
unzip tutorial-databases-data.zip

## switch to be the postgres user and create the database and add data
su - postgres
psql

## Now run commands shown in databases.html to create a database and tables and put data in the tables.

exit


###############################################################################
## Connecting to the database from outside the container within an R session
###############################################################################

library(RPostgreSQL)
drv <- dbDriver("PostgreSQL")
## Make use of port 63333 on the host machine, which maps to 5432 in the container
## as set up at the start of this file.
user = 'paciorek'  
db <- dbConnect(drv, dbname = 'wikistats', user = user,
                password = 'test', port = 63333, host = 'localhost')



