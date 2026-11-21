FROM python:3.13-slim-bookworm@sha256:a5a7017efc5969e00ae2b91c8eb0631049a569652aa4ffc4501769049ae45c72

RUN pip install --no-cache-dir 'mcp-proxy==0.15.0' 'hyperresearch[all]==0.13.3' 'mcp==1.30.0' \
    && pip check \
    && install -d -m 0700 -o 10001 -g 10001 /vault /home/hyperresearch
COPY --chmod=755 entrypoint.sh /usr/local/bin/hyperresearch-entrypoint

ENV HOME=/home/hyperresearch \
    PYTHONUNBUFFERED=1
WORKDIR /vault
USER 10001:10001
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/hyperresearch-entrypoint"]
