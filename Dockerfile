# Build stage
ARG TAG=amd64
FROM cs50/cli:${TAG} AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Unset user
USER root


# Install glibc sources for debugger
# https://github.com/Microsoft/vscode-cpptools/issues/1123#issuecomment-335867997
RUN echo "deb-src http://archive.ubuntu.com/ubuntu/ jammy main restricted" > /etc/apt/sources.list.d/_.list && \
    apt update && \
    apt install --no-install-recommends --no-install-suggests --yes \
    dpkg-dev && \
    cd /tmp && \
    apt source glibc && \
    rm --force --recursive *.dsc *.tar.* && \
    mkdir --parents /build/glibc-sMfBJT && \
    tar --create --gzip --file /build/glibc-sMfBJT/glibc.tar.gz glibc*


# Install BFG
RUN wget https://repo1.maven.org/maven2/com/madgag/bfg/1.14.0/bfg-1.14.0.jar -P /opt/share


# Install Lua 5.x
# https://www.lua.org/download.html
RUN cd /tmp && \
    curl --remote-name https://www.lua.org/ftp/lua-5.4.7.tar.gz && \
    tar xzf lua-5.4.7.tar.gz && \
    rm --force lua-5.4.7.tar.gz && \
    cd lua-5.4.7 && \
    make all install && \
    cd .. && \
    rm --force --recursive /tmp/lua-5.4.7


# Install noVNC (VNC client)
RUN cd /tmp && \
    curl --location --remote-name https://github.com/novnc/noVNC/archive/refs/tags/v1.5.0.zip && \
    unzip v1.5.0.zip && \
    rm --force v1.5.0.zip && \
    cd noVNC-1.5.0/utils && \
    curl --location --remote-name https://github.com/novnc/websockify/archive/refs/heads/master.tar.gz && \
    tar xzf master.tar.gz && \
    mv websockify-master websockify && \
    rm --force master.tar.gz && \
    cd ../.. && \
    mv noVNC-1.5.0 /opt/noVNC


# Install VS Code extensions
RUN npm install --global @vscode/vsce yarn && \
    mkdir --parents /opt/cs50/extensions && \
    cd /tmp && \
    git clone https://github.com/cs50/cs50.vsix.git && \
    cd cs50.vsix && \
    npm install && \
    vsce package && \
    mv cs50-0.0.1.vsix /opt/cs50/extensions && \
    mv python-clients/cs50vsix-client /opt/cs50/extensions && \
    cd /tmp && \
    rm --force --recursive cs50.vsix && \
    git clone https://github.com/cs50/phpliteadmin.vsix.git && \
    cd phpliteadmin.vsix && \
    npm install && \
    vsce package && \
    mv phpliteadmin-0.0.1.vsix /opt/cs50/extensions && \
    cd /tmp && \
    rm --force --recursive phpliteadmin.vsix && \
    git clone https://github.com/cs50/style50.vsix.git && \
    cd style50.vsix && \
    npm install && \
    vsce package && \
    mv style50-0.0.1.vsix /opt/cs50/extensions && \
    cd /tmp && \
    rm --force --recursive style50.vsix && \
    npm uninstall --global vsce yarn


ENV DONT_PROMPT_WSL_INSTALL=1

RUN  apt-get install -y wget gpg && \
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg && \
    install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg && \
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" |sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null && \
    rm -f packages.microsoft.gpg && \
    apt update && \
    apt install -y code

USER ubuntu

COPY ./code-server/extensions.txt /tmp/extensions.txt

# Bash script to loop through extensions and install them
RUN while read -r line; do code --install-extension $line; done < /tmp/extensions.txt

RUN code --install-extension "/opt/cs50/extensions/cs50-0.0.1.vsix" && \
    code --install-extension "/opt/cs50/extensions/phpliteadmin-0.0.1.vsix" && \
    code --install-extension "/opt/cs50/extensions/style50-0.0.1.vsix" 

# Final stage
FROM cs50/cli:${TAG}


# Unset user
USER root
ARG DEBIAN_FRONTEND=noninteractive


# Copy files from builder
COPY --from=builder /build /build
COPY --from=builder /opt /opt
COPY --from=builder /usr/local /usr/local
RUN pip3 install --no-cache-dir /opt/cs50/extensions/cs50vsix-client/ && \
    rm --force --recursive /opt/cs50/extensions/cs50vsix-client


# Set virtual display
ENV DISPLAY=":0"


# Install Ubuntu packages
# Install acl for temporarily removing ACLs via opt/cs50/bin/postCreateCommand
# https://github.community/t/bug-umask-does-not-seem-to-be-respected/129638/9
RUN apt update && \
    apt install --no-install-recommends --no-install-suggests --yes \
    acl \
    dwarfdump \
    jq \
    openbox \
    mysql-client \
    php-cli \
    php-mbstring \
    php-sqlite3 \
    x11vnc \
    xvfb && \
    apt clean


# Install GitHub CLI
RUN (type -p wget >/dev/null || (sudo apt update && sudo apt-get install wget -y)) \
    && sudo mkdir -p -m 755 /etc/apt/keyrings \
    && wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && sudo apt update \
    && sudo apt install gh -y


# Install Python packages
RUN pip3 install --no-cache-dir \
    black \
    djhtml \
    inflect==7.0.0 \
    matplotlib \
    pillow==10.4.0 \
    "pydantic<2" \
    pytz \
    setuptools


# Copy files to image
COPY ./etc /etc
COPY ./opt /opt
RUN chmod a+rx /opt/cs50/bin/* && \
    chmod a+rx /opt/cs50/phpliteadmin/bin/phpliteadmin && \
    ln --symbolic /opt/cs50/phpliteadmin/bin/phpliteadmin /opt/cs50/bin/phpliteadmin

# Enforce login shell
RUN echo "\nshopt -q login_shell || exec bash --login -i" >> /etc/bash.bashrc

# Set user
USER ubuntu

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh && \
    export EXTENSIONS_GALLERY='{"serviceUrl": "https://marketplace.visualstudio.com/_apis/public/gallery"}'

COPY --chown=ubuntu:ubuntu ./code-server/config.yaml /home/ubuntu/.config/code-server/config.yaml
COPY --chown=ubuntu:ubuntu ./code-server/settings.json /home/ubuntu/.local/share/code-server/User/settings.json
COPY --chown=ubuntu:ubuntu --from=builder /home/ubuntu/.vscode/extensions /home/ubuntu/.local/share/code-server/extensions

RUN sudo mkdir /workspaces && \
    sudo chown ubuntu:ubuntu /workspaces

RUN sudo usermod -aG root ubuntu

CMD code-server