FROM rocker/tidyverse:4.4.0
LABEL maintainer="corbettr@chop.edu"
WORKDIR /rocker-build/

# update and upgrade packages
RUN apt-get -y update --fix-missing \
    && apt-get -y upgrade \
    && apt-get -y update \
    && apt-get -y autoremove

# install mono
RUN apt-get -y install ca-certificates gnupg
RUN gpg --homedir /tmp --no-default-keyring --keyring /usr/share/keyrings/mono-official-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
RUN echo "deb [signed-by=/usr/share/keyrings/mono-official-archive-keyring.gpg] https://download.mono-project.com/repo/ubuntu stable-focal main" | tee /etc/apt/sources.list.d/mono-official-stable.list
RUN apt-get -y update

RUN apt-get -y install mono-devel

# install dependencies
RUN apt-get -y install \
    curl \
    dotnet-runtime-6.0 \
    fuse \
    git \
    man-db \
    openjdk-17-jdk \
    tar \
    unzip \
    vim \
    wget 

# install CAVATICA SBFS
RUN curl https://igor.sbgenomics.com/downloads/sbfs/install.sh -sSf | sudo sh

# install python packages
# Download and install Python 3.11
RUN cd /usr/src && \
    wget https://www.python.org/ftp/python/3.11.0/Python-3.11.0.tgz && \
    tar xzf Python-3.11.0.tgz && \
    cd Python-3.11.0 && \
    ./configure --enable-optimizations && \
    make altinstall && \
    rm -rf /usr/src/Python-3.11.0.tgz

# Setup the default python commands to use Python 3.11
RUN ln -s /usr/local/bin/python3.11 /usr/local/bin/python3 && \
    ln -s /usr/local/bin/python3.11 /usr/local/bin/python
RUN python3 -m pip install --upgrade pip
RUN pip uninstall easypqp \
    && pip install git+https://github.com/Nesvilab/easypqp.git@master \
    && pip install lxml

# create a directory with 777 permission and set it to the work directory
RUN mkdir /fragpipe_bin
RUN chmod 777 /fragpipe_bin
WORKDIR /fragpipe_bin

# create directories
RUN mkdir tmp
RUN chmod 777 tmp

# download and install fragPipe
RUN wget https://github.com/Nesvilab/FragPipe/releases/download/23.1/FragPipe-23.1-linux.zip -P fragPipe-23.1
RUN unzip fragPipe-23.1/FragPipe-23.1-linux.zip -d fragPipe-23.1
RUN chmod -R 777 /fragpipe_bin

# set environment variables
ENV JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64/"
RUN export JAVA_HOME

# copy Fragpipe dependencies 

COPY MSFragger-4.3.jar /fragpipe_bin/fragPipe-23.1/fragpipe-23.1/tools/MSFragger-4.3.jar 
COPY diaTracer-1.3.3.jar /fragpipe_bin/fragPipe-23.1/fragpipe-23.1/tools/diaTracer-1.3.3.jar
COPY IonQuant-1.11.11.jar /fragpipe_bin/fragPipe-23.1/fragpipe-23.1/tools/IonQuant-1.11.11.jar

WORKDIR /rocker-build/

ADD Dockerfile .