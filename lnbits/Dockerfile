FROM python:3.10-slim-bullseye

# massmux/lnbitspg lnbits version with postgreSQL connection

RUN apt-get clean
RUN apt-get update
RUN apt-get install -y curl pkg-config build-essential git wget

RUN curl -sSL https://install.python-poetry.org | python3 -
ENV PATH="/root/.local/bin:$PATH"

# needed for backups postgresql-client version 14 (pg_dump)
RUN apt-get install -y wget
RUN echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg.list
RUN wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN apt-get update
RUN apt-get install -y postgresql-client-14


RUN	cd /tmp && wget https://github.com/lnbits/lnbits/archive/refs/tags/0.12.10.tar.gz &&\
	tar xzvf 0.12.10.tar.gz &&\
	mv lnbits-0.12.10 /app

WORKDIR /app

RUN 	mkdir -p lnbits/data

RUN poetry config virtualenvs.create false
RUN poetry install --only main

ENV LNBITS_PORT="5000"
ENV LNBITS_HOST="0.0.0.0"

EXPOSE 5000

CMD ["sh", "-c", "poetry run lnbits --port $LNBITS_PORT --host $LNBITS_HOST"]

