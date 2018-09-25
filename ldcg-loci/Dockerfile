FROM debian:stretch-backports

COPY erp18.06.list /tmp/

RUN apt update \
	&& echo "Package: *" >> /etc/apt/preferences.d/89_stretch-backports_default \
	&& echo "Pin: release n=stretch-backports" >> /etc/apt/preferences.d/89_stretch-backports_default \
	&& echo "Pin-Priority: 500" >> /etc/apt/preferences.d/89_stretch-backports_default \
 	&& apt upgrade -y \
	&& apt dist-upgrade -y --no-install-recommends \
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
