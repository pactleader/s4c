#!/bin/bash
# =============================================================
# Deployment script for s4c.pacificpact.com
# Run this on your DigitalOcean droplet as root
# =============================================================

set -e

DOMAIN="s4c.pacificpact.com"
APP_DIR="/var/www/$DOMAIN"
REPO_URL="https://github.com/YOUR_USERNAME/s4c.git"  # <-- Update this

echo "==> Updating system packages..."
apt update && apt upgrade -y

echo "==> Installing Nginx, Certbot, Node.js..."
apt install -y nginx certbot python3-certbot-nginx curl

# Install Node.js 20 LTS via NodeSource
if ! command -v node &> /dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt install -y nodejs
fi

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

    root /var/www/s4c.pacificpact.com/dist;
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
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m your-email@example.com
# ^^^ Change the email above to your actual email

echo "==> Setting up auto-renewal..."
systemctl enable certbot.timer

echo ""
echo "====================================="
echo "  Deployment complete!"
echo "  https://$DOMAIN"
echo "====================================="
