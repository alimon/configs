FROM debian:stretch

COPY erp18.06.list /tmp/

RUN apt update \
 	&& apt upgrade -y \
 	&& apt install -y --no-install-recommends curl gnupg \
 	&& curl http://obs.linaro.org/ERP:/18.06/Debian_9/Release.key | apt-key add - \
 	&& mv /tmp/erp18.06.list /etc/apt/sources.list.d/ \
 	&& apt update \
 	&& apt install -y --no-install-recommends \
            git \
            ca-certificates \
            netbase \
            lsb-release \
            patch \
            python virtualenv \
            sudo
