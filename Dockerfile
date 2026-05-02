# ==========================================
# STAGE 1: Builder
# ==========================================
FROM pandoc/latex:latest AS builder

# Install bash, nodejs, and Alpine's native Chromium + dependencies
RUN apk add --no-cache \
    nodejs \
    npm \
    bash \
    findutils \
    coreutils \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont

# Tell Puppeteer to use the installed system Chromium instead of downloading its own
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

# Install mermaid filter
RUN npm install -g mermaid-filter

WORKDIR /docs

COPY doc-builder/build.sh /build.sh
RUN chmod +x /build.sh

COPY ./docs/ /docs/

# Create a Puppeteer config file so Chrome can run as root without sandboxing issues
# Handled in build.sh
# RUN echo '{"args": ["--no-sandbox", "--disable-setuid-sandbox"]}' > /docs/.puppeteer.json

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
