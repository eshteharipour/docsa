# ==========================================
# STAGE 1: Builder
# ==========================================
FROM pandoc/latex:latest AS builder

RUN apk add --no-cache nodejs npm bash findutils coreutils

# Install mermaid filter
RUN npm install -g mermaid-filter

WORKDIR /docs

COPY doc-builder/build.sh /build.sh
RUN chmod +x /build.sh

COPY . /docs/

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
