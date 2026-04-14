# ──────────────────────────────────────────────────────────────
# Stage 1: Build assets and install ERPNext app
# ──────────────────────────────────────────────────────────────
FROM frappe/bench:latest AS builder

ARG FRAPPE_BRANCH=version-15
ARG ERPNEXT_BRANCH=version-15

USER frappe
WORKDIR /home/frappe/frappe-bench

# Initialize bench with Frappe framework
RUN bench init --frappe-branch ${FRAPPE_BRANCH} --skip-redis-config-generation --skip-assets --python python3 /home/frappe/frappe-bench

# Copy ERPNext app source into the bench apps directory
COPY --chown=frappe:frappe . /home/frappe/frappe-bench/apps/erpnext

# Install ERPNext app and its dependencies
RUN bench get-app --skip-assets --resolve-deps file:///home/frappe/frappe-bench/apps/erpnext \
    && bench build --production

# ──────────────────────────────────────────────────────────────
# Stage 2: Production backend image (Gunicorn workers)
# ──────────────────────────────────────────────────────────────
FROM frappe/frappe-worker:${FRAPPE_BRANCH:-v15} AS backend

COPY --from=builder /home/frappe/frappe-bench/apps /home/frappe/frappe-bench/apps
COPY --from=builder /home/frappe/frappe-bench/sites /home/frappe/frappe-bench/sites
COPY --from=builder /home/frappe/frappe-bench/env /home/frappe/frappe-bench/env

# ──────────────────────────────────────────────────────────────
# Stage 3: Production frontend image (Nginx)
# ──────────────────────────────────────────────────────────────
FROM frappe/frappe-nginx:${FRAPPE_BRANCH:-v15} AS frontend

COPY --from=builder /home/frappe/frappe-bench/sites/assets /usr/share/nginx/html/assets

# Default target is backend
FROM backend
