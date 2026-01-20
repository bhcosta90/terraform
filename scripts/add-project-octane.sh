#!/usr/bin/env bash
set -e

PROJECT_NAME="$1"
DOMAIN="$2"
REDIS_DB="$3"

if [ -z "$PROJECT_NAME" ] || [ -z "$DOMAIN" ] || [ -z "$REDIS_DB" ]; then
  echo "Uso:"
  echo "add-project-octane.sh projeto-a projeto-a.com 0"
  exit 1
fi

BASE_DIR="/var/www"
PROJECT_DIR="$BASE_DIR/$PROJECT_NAME"
CURRENT_DIR="$PROJECT_DIR/current"

DB_NAME="${PROJECT_NAME}_db"
DB_USER="${PROJECT_NAME}_user"
DB_PASS=$(openssl rand -base64 16)

PHP_VERSION="8.2"

# =========================
# PORTA DINÂMICA
# =========================
get_free_port() {
  local start=8000
  local end=9000

  for ((port=$start; port<=$end; port++)); do
    if ! ss -lnt | awk '{print $4}' | grep -q ":$port$"; then
      echo $port
      return
    fi
  done

  echo "❌ Nenhuma porta livre encontrada"
  exit 1
}

PORT=$(get_free_port)

# =========================
# DIRETORIOS
# =========================
mkdir -p "$CURRENT_DIR"
chown -R www-data:www-data "$PROJECT_DIR"

# =========================
# MYSQL
# =========================
mysql <<EOF
CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF

# =========================
# NGINX (HTTP INICIAL)
# =========================
NGINX_CONF="/etc/nginx/sites-available/$PROJECT_NAME"

cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_http_version 1.1;

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

ln -s "$NGINX_CONF" /etc/nginx/sites-enabled/
nginx -t
systemctl reload nginx

# =========================
# SSL AUTOMÁTICO (CERTBOT)
# =========================
certbot --nginx \
  -d "$DOMAIN" \
  --non-interactive \
  --agree-tos \
  -m admin@"$DOMAIN" \
  --redirect

# =========================
# SUPERVISOR (OCTANE)
# =========================
SUPERVISOR_CONF="/etc/supervisor/conf.d/octane-$PROJECT_NAME.conf"

cat > "$SUPERVISOR_CONF" <<EOF
[program:octane-$PROJECT_NAME]
directory=$CURRENT_DIR
command=/usr/bin/php artisan octane:start --server=swoole --host=127.0.0.1 --port=$PORT --workers=4 --max-requests=500
autostart=true
autorestart=true
user=www-data
redirect_stderr=true
stdout_logfile=/var/log/octane/$PROJECT_NAME.log
stopwaitsecs=10
killasgroup=true
stopasgroup=true
EOF

mkdir -p /var/log/octane
chown -R www-data:www-data /var/log/octane

supervisorctl reread
supervisorctl update

# =========================
# OUTPUT FINAL
# =========================
echo ""
echo "✅ Projeto criado com HTTPS automático!"
echo ""
echo "🌐 Domínio: https://$DOMAIN"
echo "⚡ Porta Octane (interna): $PORT"
echo ""
echo "🗄️ MySQL:"
echo "DB_DATABASE=$DB_NAME"
echo "DB_USERNAME=$DB_USER"
echo "DB_PASSWORD=$DB_PASS"
echo ""
echo "⚡ Redis:"
echo "REDIS_DB=$REDIS_DB"
echo ""
echo "➡️ Próximos passos:"
echo "1) git clone SEU_REPO $CURRENT_DIR"
echo "2) cp .env.example .env"
echo "3) Preencher DB / Redis no .env"
echo "4) composer install"
echo "5) php artisan key:generate"
echo "6) php artisan migrate"
