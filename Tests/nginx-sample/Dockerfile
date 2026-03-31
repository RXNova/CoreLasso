FROM nginx:alpine

# Copy static site files into the default nginx html directory
COPY ./html /usr/share/nginx/html

# Optional: override the default nginx config
# COPY nginx.conf /etc/nginx/nginx.conf

# Declare volumes that should be externally mounted
# - logs: nginx access and error logs
# - cache: nginx temporary cache files
VOLUME ["/var/log/nginx", "/var/cache/nginx"]

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
