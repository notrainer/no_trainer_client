FROM ghcr.io/b3n4kh/nmap:latest@sha256:d939755e48a65b8c2b0cc2262b0795665dd5bbe67b8ce373774f1b84e834140f AS zenmap
FROM lscr.io/linuxserver/webtop:fedora-xfce@sha256:953cf5572a4834bb28b127e2253fd3f1cbc4fead64ff96c5c8d066c281061d8a AS webtop
FROM webtop

# The base image skips documentation; keep manuals and restore any inherited packages' pages.
RUN sed -i '/^[[:space:]]*tsflags[[:space:]]*=/d' /etc/dnf/dnf.conf \
    && dnf update -y && dnf install -y bash-completion man man-pages nmap openssh-server iputils iproute vim \
    python3 lua wireshark wireshark-cli tcpdump curl bind-utils nmap-ncat git samba-client postgresql diffutils xmlstarlet \
    && usermod -aG wireshark abc \
    && wireshark --version > /dev/null \
    && dnf reinstall -y nmap man-pages \
    && man -P cat nmap > /dev/null
COPY /etc /etc
RUN ln -s /etc/nmap-training /opt/nmap-training \
    && mkdir -p /custom-cont-init.d \
    && ln -s /etc/nmap-training/init-training.sh /custom-cont-init.d/50-nmap-training.sh \
    && chmod -R a+rX /etc/nmap-training \
    && chmod a+r /etc/profile.d/nmap-training.sh \
    && chmod a+rx /etc/nmap-training/init-training.sh /etc/s6-overlay/s6-rc.d/svc-openssh-server/run \
    && chmod a+rx /etc/nmap-training/scripts/nmap-sage \
    && ln -s /etc/nmap-training/scripts/nmap-sage /usr/local/bin/nmap-sage \
    && passwd -l abc
RUN lua -v && for script in /etc/nmap-training/examples/*.lua; do luac -p "$script"; done

### NMAP ###

RUN dnf install -y python3-pip cairo-devel pkg-config python3-devel python3-cairo python3-cairo-devel gobject-introspection-devel cairo-gobject-devel
COPY --from=zenmap /nmap/zenmap/zenmap /usr/local/bin/zenmap
COPY --from=zenmap /nmap/zenmap/dist/zenmap-7.95+svn-py3-none-any.whl /tmp/zenmap-7.95+svn-py3-none-any.whl
COPY --from=zenmap /nmap/zenmap/zenmapCore/data/pixmaps/zenmap.png /usr/share/icons/zenmap.png
COPY --from=zenmap /nmap/zenmap/install_scripts/unix/zenmap.desktop /usr/share/applications/zenmap.desktop

RUN pip install /tmp/zenmap-7.95+svn-py3-none-any.whl

############

# Fedora updates replace Webtop's patched Xvfb and break dynamic resolution.
COPY --from=webtop /usr/bin/Xvfb /usr/bin/Xvfb
COPY tests/check_display.sh /tmp/check_display.sh
RUN bash /tmp/check_display.sh && rm /tmp/check_display.sh

EXPOSE 2222
