FROM pandoc/latex:latest

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

# Install the official Mermaid CLI
RUN npm install -g @mermaid-js/mermaid-cli

# Setup default paths for the one-off executable
ENV DOCS_SRC=/docs \
    OUTPUT_DIR=/output \
    SKIP_AUTO_INDEX=false

COPY docsa/build.sh /usr/local/bin/build.sh
RUN chmod +x /usr/local/bin/build.sh

# The container will naturally run build.sh when launched
ENTRYPOINT ["/usr/local/bin/build.sh"]
