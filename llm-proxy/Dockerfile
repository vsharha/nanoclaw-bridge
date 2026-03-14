FROM python:3.12-slim

ARG PROXY_SHA=dd4a29aff3b470710187505daaeed20ea025e5bf

RUN apt-get update && apt-get install -y git && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN git clone https://github.com/1rgs/claude-code-proxy.git . && git checkout ${PROXY_SHA}

RUN pip install uv && uv sync

EXPOSE 8082

CMD ["uv", "run", "uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8082"]
