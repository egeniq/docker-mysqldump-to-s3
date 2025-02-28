FROM debian:stable-slim

COPY mysqldump-to-s3.sh /root/mysqldump-to-s3.sh

RUN \
  apt-get update && apt-get install -y default-mysql-client awscli curl && rm -rf /var/lib/apt/lists/* && \
  chmod a+x /root/mysqldump-to-s3.sh && \
  mkdir /dumps

ENTRYPOINT ["/bin/bash", "/root/mysqldump-to-s3.sh"]
