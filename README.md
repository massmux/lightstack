# Full Phoenixd implementation

includes phoenixd + nginx (with lets encrypt certificate) + lnbits


## Installation

### Get the repo

```
cd ~
git clone https://github.com/massmux/phoenixd-docker
cd phoenixd-docker
```

### Choose domain and cnames

choose two subdomains on your domain, where you have the DNS management. In my example they are

- n1.yourdomain.com
- lb1.yourdomain.com

n1 will be the endpoint for phoenixd APIs
lb1 will be the lnbits install

### Create letsencrypt certificates

for each subdomain do:

```
sudo certbot certonly --manual --preferred-challenges dns
```
now copy the letsencrypt folder to the app folder

```
sudo cp -R /etc/letsencrypt ~/phoenixd-docker
```

### Configure domains (file default.conf)

set the correct domains names in default.conf to point to your cnames and to correct certificate location

### Edit docker-compose.yml

set your preferred postgreSQL password there

### Create the .env file

```
cp .env.example .env
```

now do the first edit to the file at the end of the file itself. It will be necessary to edit it again later.
at this moment put the postgreSQL password you set in docker-compose.yml file

### First temporary boot

Now you need to boot the first time the system in order to let it initialize basic files. So run

```
docker compose up
```
and see the logs.

When all booted stop it with CTRL-C and wait it to shutdown. The system has created a lot of files in the ~/phoenixd-docker directory and you need to configure some settings as described below

### Final configuration

edit the file data/phoenix.conf by adding on top of file

```
http-bind-ip=0.0.0.0
```

then copy the http-password value and update the .env file (on the bottom) with such a value (PHOENIXD_API_PASSWORD)
that's all.

### Boot

now you can run the system in this way

```
docker compose up -d
```

check the logs if all is ok

```
docker-compose logs -t -f --tail 300
```

then access to LNBITS at: https://lb1.yourdomain.com

in case you want to tune your configuration you can always setup the .env file as you prefer.



 
