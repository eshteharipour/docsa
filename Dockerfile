# ==========================================
# STAGE 1: Builder
# ==========================================
FROM pandoc/latex:latest AS builder

# Install only the necessary shell utilities (bash, find, sort, nproc, etc.)
# Node.js, Chromium, and mermaid-filter have been removed since we now render SVGs client-side!
RUN apk add --no-cache \
    bash \
    findutils \
    coreutils

WORKDIR /docs

COPY docsa/build.sh /build.sh
RUN chmod +x /build.sh

COPY ./docs/ /docs/

# Override the default Pandoc entrypoint to run the build script.
ENTRYPOINT ["/bin/bash"]
RUN /build.sh

# ==========================================
# STAGE 2: Web Server
# ==========================================
FROM nginx:alpine

# Copy the finished HTML files from the builder stage.
COPY --from=builder /htmls /usr/share/nginx/html

EXPOSE 80
