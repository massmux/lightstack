FROM debian:12.6-slim
RUN apt-get update
RUN apt-get install -y curl wget unzip libcurl4-gnutls-dev libsqlite3-dev


WORKDIR /app
RUN 	cd /app && wget https://github.com/ACINQ/phoenixd/releases/download/v0.6.0/phoenixd-0.6.0-linux-x64.zip &&\
	unzip -j phoenixd-0.6.0-linux-x64.zip 


CMD [ "./phoenixd" ]

