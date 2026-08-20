FROM nginx:1.27

COPY html/index.html /usr/share/nginx/html/index.html

CMD ["sh", "-c", "echo 'Intentional failure for rollback test'; exit 1"]

EXPOSE 80
