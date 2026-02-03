FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        gnupg \
        ruby-full \
        sudo \
        tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash runner \
    && echo "runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner \
    && chmod 0440 /etc/sudoers.d/runner

WORKDIR /home/runner/dotfiles
COPY . /home/runner/dotfiles
RUN chown -R runner:runner /home/runner/dotfiles \
    && chmod +x /home/runner/dotfiles/bin/dotf \
    && chmod +x /home/runner/dotfiles/bin/bootstrap

USER runner
ENV HOME=/home/runner

CMD ["/bin/bash"]
