# Multi-stage build — the most important Docker pattern for CI/CD.
#
# Stage 1 (builder): Has all development tools. We install dependencies here.
# Stage 2 (production): Copies ONLY what the app needs to run — no dev tools,
#   no test frameworks, no unnecessary packages. Smaller image = smaller attack surface.
#
# The pipeline builds this image AFTER tests pass.
# If tests fail, we never build a broken image. That is the point.

# ── Stage 1: Build environment ────────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /app

# Install dependencies first (before copying app code).
# Docker caches each layer. If requirements.txt has not changed, this layer
# is served from cache even when app code changes — making builds much faster.
COPY requirements.txt .
RUN pip install --upgrade pip --no-cache-dir && \
    pip install --no-cache-dir -r requirements.txt


# ── Stage 2: Production image ──────────────────────────────────────────────────
FROM python:3.12-slim AS production

WORKDIR /app

# Security: run the application as a non-root user.
# If someone exploits a bug in the app, they get the `appuser` account,
# not root access to the host.
RUN groupadd --system appuser && \
    useradd --system --gid appuser --no-create-home appuser

# Copy only the installed packages from the builder stage (not dev tools)
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin/gunicorn /usr/local/bin/gunicorn

# Copy application source code
COPY app/ ./app/

# Switch to non-root user before starting the process
USER appuser

# Document which port the app listens on (does not actually publish it)
EXPOSE 5000

# Health check: Docker itself monitors the container and marks it unhealthy
# if this command fails repeatedly. Kubernetes uses its own probes instead,
# but this is still useful for plain Docker deployments.
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')" || exit 1

# Production server: Gunicorn with 2 worker processes.
# The Flask built-in server (flask run) is single-threaded and not safe for production.
CMD ["gunicorn", \
     "--bind", "0.0.0.0:5000", \
     "--workers", "2", \
     "--timeout", "30", \
     "--access-logfile", "-", \
     "--error-logfile", "-", \
     "app:create_app()"]
