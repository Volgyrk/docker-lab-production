# Build stage
FROM python:3.12-alpine as builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache gcc musl-dev linux-headers

# Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# Runtime stage
FROM python:3.12-alpine

WORKDIR /app

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -u 1000 -G appuser -s /bin/sh -D appuser

# Copy installed packages from builder stage
COPY --from=builder /root/.local /home/appuser/.local
COPY app ./app

# Create necessary directories for read-only mode
RUN mkdir -p /tmp /var/tmp && \
    chown -R appuser:appuser /app /tmp /var/tmp

# Environment variables
ENV PATH=/home/appuser/.local/bin:$PATH
ENV PYTHONPATH=/app
ENV ROCKET_SIZE=Small
ENV PORT=8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget -qO- http://localhost:${PORT}/health || exit 1

# Labels
ARG LAB_LOGIN
ARG LAB_TOKEN
LABEL org.lab.login=$LAB_LOGIN
LABEL org.lab.token=$LAB_TOKEN

USER appuser

EXPOSE 8000

# Use Gunicorn with tmp directory flag
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--worker-tmp-dir", "/dev/shm", "--access-logfile", "-", "app.app:app"]