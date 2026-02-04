FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    ffmpeg && apt-get clean\
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN pip install --no-cache-dir --upgrade pip

COPY requirements.txt .

RUN pip install --no-cache-dir --default-timeout=100 -r requirements.txt

COPY . .

CMD ["python", "main.py"]