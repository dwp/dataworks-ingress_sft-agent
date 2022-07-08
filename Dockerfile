FROM ubuntu:18.04
ENV S3FS_VERSION v1.88
ARG DEBIAN_FRONTEND=noninteractive
ENV acm_cert_helper_version="0.37.0"
ARG jmx_exporter_version="0.15.0"


RUN apt-get update && apt-get install -y ca-certificates util-linux curl g++ gcc musl-dev libffi-dev gcc cargo apt-utils python-pip git automake autotools-dev fuse libcurl4-gnutls-dev libfuse-dev libssl-dev libxml2-dev make pkg-config awscli uuid-runtime devscripts dselect aptitude s3fs
RUN pip install https://github.com/dwp/acm-pca-cert-generator/releases/download/${acm_cert_helper_version}/acm_cert_helper-${acm_cert_helper_version}.tar.gz
RUN git config --global http.sslVerify false
RUN git clone --depth 1 --branch ${S3FS_VERSION} https://github.com/s3fs-fuse/s3fs-fuse.git
RUN cd s3fs-fuse && \
    ./autogen.sh && \
    ./configure --prefix=/opt/s3fs-fuse && \
    make && \
    make install

RUN mkdir -p /mnt/point
RUN mkdir -p /mnt/stage_point
RUN mkdir app
RUN mkdir -p data-ingress
RUN mkdir -p /opt/data-ingress
RUN mkdir -p /mnt/point/e2e/eicar_test

WORKDIR /app
VOLUME [ "/data-ingress" ]

COPY sft-agent-jre8-2.3.1a4ce31c2971dc408da388c33f4228e73ecbaa2548b5a9cbf6528d6657210d71c.jar sft-agent.jar
COPY entrypoint.sh ./
RUN mkdir -p /opt/jmx_exporter
COPY ./jmx_exporter_config.yml /opt/jmx_exporter/
RUN curl -L https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${jmx_exporter_version}/jmx_prometheus_javaagent-${jmx_exporter_version}.jar -o /opt/jmx_exporter/jmx_exporter.jar

# Set user to run the process as in the docker contianer
ENV USER_NAME=root
ENV GROUP_NAME=root
RUN chown -R $USER_NAME.$GROUP_NAME /etc/ssl/
RUN chown -R $USER_NAME.$GROUP_NAME /usr/local/share/ca-certificates/
RUN chown -R $USER_NAME.$GROUP_NAME /app
RUN chown -R $USER_NAME.$GROUP_NAME /var
RUN chown -R $USER_NAME.$GROUP_NAME /mnt/point
RUN chown -R $USER_NAME.$GROUP_NAME /mnt/stage_point
RUN chown -R $USER_NAME.$GROUP_NAME /mnt/point/e2e/eicar_test/
RUN chown -R $USER_NAME.$GROUP_NAME /opt/data-ingress
RUN chmod g+rwX /data-ingress
RUN chmod a+rw /var/log
RUN chmod -R 075 /mnt
RUN chmod 075 entrypoint.sh
USER $USER_NAME
EXPOSE 8080
ENTRYPOINT ["./entrypoint.sh"]
