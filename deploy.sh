#!/bin/bash
# =============================================================
# Deployment script for s4c.pacificpact.com
# Run this on your DigitalOcean droplet as root
# =============================================================

set -e

DOMAIN="s4c.pacificpact.com"
APP_DIR="/var/www/html/$DOMAIN"
REPO_URL="https://github.com/pactleader/s4c.git"

echo "==> Cloning repo and building..."
rm -rf "$APP_DIR"
git clone "$REPO_URL" "$APP_DIR"
cd "$APP_DIR"
npm install
npm run build

echo "==> Configuring Nginx..."
cat > /etc/nginx/sites-available/$DOMAIN <<'NGINX'
server {
    listen 80;
    listen [::]:80;
    server_name s4c.pacificpact.com;

    root /var/www/html/s4c.pacificpact.com/dist;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff2?)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
}
NGINX

# Enable the site
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

echo "==> Testing Nginx config..."
nginx -t

echo "==> Restarting Nginx..."
systemctl restart nginx

echo "==> Obtaining SSL certificate with Let's Encrypt..."
certbot --nginx -d $DOMAIN

echo ""
echo "====================================="
echo "  Deployment complete!"
echo "  https://$DOMAIN"
echo "====================================="
