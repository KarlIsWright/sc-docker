FROM starcraft:game

# Switch to root for package installation
USER root

# Install X11 components, VNC server, and debugging tools
RUN set -x \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends \
    xauth \
    kde-cli-tools \
    procps \
    psmisc \
    htop \
    nano \
    vim \
    wget \
    curl \
    net-tools \
    xvfb \
    x11vnc \
    strace \
    tcpdump \
    tshark \
    wireshark-common \
    netstat-nat \
    lsof \
    gdb \
    ltrace \
    && rm -rf /var/lib/apt/lists/*

# Copy debugging scripts
COPY --chown=starcraft:users scripts/internal_network_debug.sh /app/scripts/internal_network_debug.sh
COPY --chown=starcraft:users scripts/internal_network_analysis.sh /app/scripts/internal_network_analysis.sh
COPY --chown=starcraft:users scripts/auto_debug_startup.sh /app/scripts/auto_debug_startup.sh
COPY --chown=starcraft:users scripts/patch_play_common.sh /app/scripts/patch_play_common.sh
COPY --chown=starcraft:users scripts/patch_debug_gui.sh /app/scripts/patch_debug_gui.sh

# Make scripts executable
RUN chmod +x /app/scripts/internal_network_debug.sh \
    && chmod +x /app/scripts/internal_network_analysis.sh \
    && chmod +x /app/scripts/auto_debug_startup.sh \
    && chmod +x /app/scripts/patch_play_common.sh \
    && chmod +x /app/scripts/patch_debug_gui.sh

# Switch to starcraft user
USER starcraft
# Keep the working directory as /app (inherited from starcraft:game)
WORKDIR /app

# Integrate auto-debugging into play_common.sh
RUN /app/scripts/patch_play_common.sh

# Apply debug GUI patch to always start VNC in debug mode
RUN /app/scripts/patch_debug_gui.sh

RUN winetricks -q --force cmd

# RUN winetricks -q --force wininet winhttp urlmon directplay vcrun2022

# Install Bonjour Print Services for LAN game discovery
# COPY --chown=starcraft:users BonjourPSSetup.exe /home/starcraft/BonjourPSSetup.exe
# COPY --chown=starcraft:users install_bonjour.sh /home/starcraft/install_bonjour.sh
# COPY --chown=starcraft:users SC_Inst_Lite.exe /home/starcraft/SC_Inst_Lite.exe

# RUN /home/starcraft/install_bonjour.sh

# USER root
# RUN rm /home/starcraft/BonjourPSSetup.exe /home/starcraft/install_bonjour.sh



# Set up Wine environment variables for VNC
ENV DISPLAY=:0
ENV WINEARCH=win32
ENV WINEPREFIX=/home/starcraft/.wine

# Expose VNC port
EXPOSE 5900

# Create a startup script for VNC + Wine desktop with auto-debugging
RUN echo '#!/bin/bash' > /home/starcraft/start_vnc_desktop.sh \
    && echo 'echo "Starting Xvfb virtual display..."' >> /home/starcraft/start_vnc_desktop.sh \
    && echo 'Xvfb :0 -auth ~/.Xauthority -screen 0 1280x720x24 > /tmp/xvfb.log 2>&1 &' >> /home/starcraft/start_vnc_desktop.sh \
    && echo 'sleep 2' >> /home/starcraft/start_vnc_desktop.sh \
    && echo 'echo "Starting VNC server on :0 (port 5900)..."' >> /home/starcraft/start_vnc_desktop.sh \
    && echo 'x11vnc -forever -nopw -display :0 > /tmp/vnc.log 2>&1 &' >> /home/starcraft/start_vnc_desktop.sh \
    && echo 'sleep 2' >> /home/starcraft/start_vnc_desktop.sh \
    && echo 'echo "Starting Wine desktop environment..."' >> /home/starcraft/start_vnc_desktop.sh \
    && echo 'echo "VNC server running on port 5900"' >> /home/starcraft/start_vnc_desktop.sh \
    && echo 'echo "Connect with: vncviewer localhost:5900"' >> /home/starcraft/start_vnc_desktop.sh \
    && echo '' >> /home/starcraft/start_vnc_desktop.sh \
    && echo '# Start auto-debugging if enabled' >> /home/starcraft/start_vnc_desktop.sh \
    && echo '/app/scripts/auto_debug_startup.sh &' >> /home/starcraft/start_vnc_desktop.sh \
    && echo '' >> /home/starcraft/start_vnc_desktop.sh \
    && echo 'wine explorer /desktop=debug,1280x720' >> /home/starcraft/start_vnc_desktop.sh \
    && chmod +x /home/starcraft/start_vnc_desktop.sh

# Set default command to run VNC desktop environment
CMD ["/home/starcraft/start_vnc_desktop.sh"]
