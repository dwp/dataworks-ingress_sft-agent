FROM python:3.8.10-alpine3.13
ENV S3FS_VERSION v1.90
ENV acm_cert_helper_version="0.37.0"

RUN echo "installing dependencies" \
&& apk update \
&& apk upgrade \
&& apk add --no-cache ca-certificates \
&& apk add --no-cache util-linux \
&& apk add --no-cache curl \
&& apk add --no-cache sudo \
&& apk add --no-cache openjdk11-jre \
&& apk add --no-cache git \
&& apk add --no-cache zip \
&& apk add --no-cache build-base alpine-sdk automake autoconf fuse-dev curl-dev libxml2-dev fuse libressl-dev \
&& apk add --no-cache g++ gcc musl-dev libffi-dev openssl-dev cargo jq aws-cli \
&& pip3 install --upgrade pip \
&& pip3 install https://github.com/dwp/acm-pca-cert-generator/releases/download/${acm_cert_helper_version}/acm_cert_helper-${acm_cert_helper_version}.tar.gz

RUN git config --global http.sslVerify false
RUN git clone --depth 1 --branch ${S3FS_VERSION} https://github.com/s3fs-fuse/s3fs-fuse.git

RUN cd s3fs-fuse && \
    ./autogen.sh && \
    ./configure --prefix=/opt/s3fs-fuse && \
    make && \
    make install

RUN mkdir -p /mnt/point
RUN mkdir -p /mnt/point/data-ingress
RUN mkdir -p /mnt/trend_micro_test
RUN mkdir -p /mnt/send_point
RUN mkdir -p app
RUN mkdir -p app-route-test
RUN mkdir -p /opt/data-ingress
RUN mkdir -p /mnt/point/e2e/eicar_test

WORKDIR /app

COPY sft-agent-3.0.6.jar sft-agent.jar
COPY entrypoint.sh ./

ENV USER_NAME=root
ENV GROUP_NAME=root
RUN chown -R $USER_NAME.$GROUP_NAME /mnt
RUN chown -R $USER_NAME.$GROUP_NAME /mnt/send_point
RUN chown -R $USER_NAME.$GROUP_NAME /mnt/point
RUN chown -R $USER_NAME.$GROUP_NAME /mnt/trend_micro_test
RUN chown -R $USER_NAME.$GROUP_NAME /etc/ssl/
RUN chown -R $USER_NAME.$GROUP_NAME /usr/local/share/ca-certificates/
RUN chown -R $USER_NAME.$GROUP_NAME /app
RUN chown -R $USER_NAME.$GROUP_NAME /app-route-test
RUN chown -R $USER_NAME.$GROUP_NAME /var
RUN chown -R $USER_NAME.$GROUP_NAME /opt/data-ingress
RUN chown -R $USER_NAME.$GROUP_NAME /mnt/point/e2e/eicar_test/
RUN chmod a+rw /var/log

RUN chmod -R 0755 /mnt
RUN chmod -R 0755 /mnt/point
RUN chmod -R 0755 /mnt/point/e2e/eicar_test/
RUN chmod -R 0755 /mnt/trend_micro_test
RUN chmod 0755 entrypoint.sh

USER $USER_NAME

EXPOSE 8080
EXPOSE 8081
EXPOSE 8091

ENTRYPOINT ["./entrypoint.sh"]
