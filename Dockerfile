FROM nginx:1.27

COPY html/index.html /usr/share/nginx/html/index.html

EXPOSE 80
