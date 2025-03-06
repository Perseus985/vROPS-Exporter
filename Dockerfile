FROM python:3.9-slim

WORKDIR /app

# Copy exporter script
COPY vrops_exporter.py /app/

# Install dependencies
RUN pip install --no-cache-dir prometheus-client requests

# Create a non-root user to run the exporter
RUN useradd -r -u 1000 exporter && \
    chown -R exporter:exporter /app

USER exporter

# Expose the default port
EXPOSE 9000

ENTRYPOINT ["python", "vrops_exporter.py"]
CMD ["--host "$(VROPS_HOST)" --username "$VROPS_USERNAME" --password "$VROPS_PASSWORD" --exporter-port 9000 --interval 300 --no-verify-ssl --batch-size 100 --worker-threads 5 --resource-batch-size 50 --metric-batch-size 1000"]