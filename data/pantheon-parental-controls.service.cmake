[Unit]
Description=Pantheon Parental Controls Daemon

[Service]
Type=dbus
Restart=always
BusName=org.pantheon.ParentalControls
ExecStart=@CMAKE_INSTALL_PREFIX@/bin/pantheon-parental-controls-daemon

[Install]
WantedBy=multi-user.target