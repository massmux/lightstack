# Full Phoenixd Stack

 Just run your own self-custodial cloud Lightning node on your VPS, from your domain name, with this stack. You immediately get a LNBits instance on your own node and the phoenixd endpoint available on a SSL connection


## Installation

### Get the repo

```
cd ~
git clone https://github.com/massmux/phoenixd-docker
cd phoenixd-docker
```

### Choose domain and cnames

choose two subdomains on your domain, where you have the DNS management. They must point the A record to the host server IP and this must be already propagated when you are going to invoke initialization script. In my example they are

- n1.yourdomain.com
- lb1.yourdomain.com

n1 will be the endpoint for phoenixd APIs
lb1 will be the lnbits install

### Initialize


```
cd phoenixd-docker
./init.sh

```
In case you need to start inizialization from the beginning, you need to clear existing configuration by issuing:

```
./init.sh clear
```


### Access

Access LNBITS at:

- https://lb1.yourdomain.com

Access phoenixd API endpoint with:

- https://n1.yourdomain.com
- http password: provided in phoenix.conf file

in case you want to tune your configuration you can always setup the .env file as you prefer.

 
