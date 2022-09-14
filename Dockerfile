#REF: https://aws.amazon.com/blogs/aws/new-for-aws-lambda-container-image-support/
#REF: https://docs.aws.amazon.com/lambda/latest/dg/python-image.html
#REF: https://wiki.documentfoundation.org/Development/BuildingOnLinux
ARG SRC_URL="https://download.documentfoundation.org/libreoffice/src/7.4.1/libreoffice-7.4.1.2.tar.xz"
ARG LO_VERSION="7.4.1.2"

ARG MAIN_FUNCTION_DIR="/app/"
ARG PYTHON_RUNTIME_VERSION="3.8"

FROM python:${PYTHON_RUNTIME_VERSION} as build-image
ARG MAIN_FUNCTION_DIR
ARG PYTHON_RUNTIME_VERSION
ARG LO_VERSION
ARG SRC_URL

RUN useradd -u 1000 -U -ms /bin/bash user
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y && \
    apt-get install -y git build-essential zip ccache junit4 libkrb5-dev nasm graphviz python3 python3-dev qtbase5-dev libkf5coreaddons-dev libkf5i18n-dev libkf5config-dev libkf5windowsystem-dev libkf5kio-dev autoconf libcups2-dev libfontconfig1-dev gperf default-jdk doxygen libxslt1-dev xsltproc libxml2-utils libxrandr-dev libx11-dev bison flex libgtk-3-dev libgstreamer-plugins-base1.0-dev libgstreamer1.0-dev ant ant-optional libnss3-dev libavahi-client-dev libxt-dev && \
    rm -rf /var/lib/apt/lists/* && mkdir /src && chown user:user /src

ADD ${SRC_URL} /src/libreoffice-${LO_VERSION}.tar.xz
RUN mkdir -p ${MAIN_FUNCTION_DIR} && chown user:user -R ${MAIN_FUNCTION_DIR} /src
USER user
WORKDIR /src
# Compile, install to /src/libreoffice, then find all lib using ldd, then reverse find what packages (deb) provide those libs, then put in pkg.lst file for next phase to install
RUN cd /src && mkdir -p libreoffice && tar xf libreoffice-${LO_VERSION}.tar.xz && cd /src/libreoffice-${LO_VERSION} && \
    ./configure \
    --disable-avahi \
    --disable-cairo-canvas \
    --disable-coinmp \
    --disable-cups \
    --disable-cve-tests \
    --disable-dbus \
    --disable-dconf \
    --disable-dependency-tracking \
    --disable-evolution2 \
    --disable-dbgutil \
    --disable-extension-integration \
    --disable-extension-update \
    --disable-firebird-sdbc \
    --disable-gio \
    --disable-gstreamer-1-0 \
    --disable-gtk3-kde5 \
    --disable-gtk3 \
    --disable-introspection \
    --disable-largefile \
    --disable-lotuswordpro \
    --disable-lpsolve \
    --disable-odk \
    --disable-ooenv \
    --disable-pch \
    --disable-postgresql-sdbc \
    --disable-python \
    --disable-randr \
    --disable-report-builder \
    --disable-scripting-beanshell \
    --disable-scripting-javascript \
    --disable-sdremote \
    --disable-sdremote-bluetooth \
    --enable-mergelibs \
    --with-galleries="no" \
    --with-system-curl \
    --with-system-expat \
    --with-system-libxml \
    --with-system-nss \
    --with-system-openssl \
    --with-theme="no" \
    --without-export-validation \
    --without-fonts \
    --without-helppack-integration \
    --without-java \
    --without-junit \
    --without-krb5 \
    --without-myspell-dicts \
    --without-system-dicts \
    --prefix=/src/libreoffice && make  && make install && \
    find /src/libreoffice -type f -executable -exec ldd '{}' \; | sed 's/(.*)//g' | sort | uniq | grep -v '/src/libreoffice'| sed -e 's/^[[:space:]]*//' | cut -d' ' -f1 | grep -v 'statically' | grep -v 'linux-vdso.so.1' | xargs dpkg -S | cut -d":" -f1 | sort | uniq | tr '\n' ' ' > /src/libreoffice/pkg.lst

# Copy handler function
COPY app/* ${MAIN_FUNCTION_DIR}
# Install AWS Lambda runtime
RUN python${PYTHON_RUNTIME_VERSION} -m pip install awslambdaric --target ${MAIN_FUNCTION_DIR}

FROM python:${PYTHON_RUNTIME_VERSION}-slim
ARG MAIN_FUNCTION_DIR
ENV DEBIAN_FRONTEND=noninteractive
WORKDIR ${MAIN_FUNCTION_DIR}
RUN useradd -u 1000 -U -ms /bin/bash user && mkdir -p /src/libreoffice
COPY --from=build-image ${MAIN_FUNCTION_DIR} ${MAIN_FUNCTION_DIR}
COPY --from=build-image /src/libreoffice /src/libreoffice
RUN apt-get update -y && apt-get install -y $(cat /src/libreoffice/pkg.lst) && rm -rf /var/lib/apt/lists/*
ADD https://github.com/aws/aws-lambda-runtime-interface-emulator/releases/latest/download/aws-lambda-rie /usr/bin/aws-lambda-rie
COPY entry.sh /
RUN chmod 755 /usr/bin/aws-lambda-rie /entry.sh
ENTRYPOINT [ "/entry.sh" ]
CMD [ "app.handler" ]
