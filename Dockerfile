FROM pandoc/latex:latest

RUN apk add --no-cache \
    nodejs \
    npm \
    nginx \
    bash

# Install mermaid filter
RUN npm install -g mermaid-filter

# Work directory for markdown docs
WORKDIR /docs

# Copy build assets
COPY build.sh /build.sh
COPY nginx.conf /etc/nginx/nginx.conf

RUN chmod +x /build.sh

EXPOSE 80
CMD ["/bin/bash", "-c", "/build.sh && nginx -g 'daemon off;'"]
