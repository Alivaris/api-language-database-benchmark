FROM python:3.13-slim

WORKDIR /app

RUN pip install --no-cache-dir cassandra-driver

COPY load.py /app/load.py

CMD ["python", "/app/load.py"]
