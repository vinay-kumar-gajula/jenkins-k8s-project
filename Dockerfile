FROM nginx:1.27

RUN printf 'server {\n\
    listen 80;\n\
    location / {\n\
        return 500;\n\
    }\n\
}\n' > /etc/nginx/conf.d/default.conf

EXPOSE 80
