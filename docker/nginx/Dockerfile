# ============================================================
# nginx – SSL reverse proxy for OpenClaw (Tailscale HTTPS)
# ============================================================
FROM nginx:alpine

# gettext provides envsubst for template substitution
RUN apk add --no-cache gettext

COPY nginx.conf.tpl /etc/nginx/nginx.conf.tpl
COPY entrypoint.sh  /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80 443

CMD ["/entrypoint.sh"]
