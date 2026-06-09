# Managed by Jetpack (expanso-edge role) -- do not edit by hand.
[Unit]
Description=Expanso Edge agent ({{ expanso_edge_version }})
Documentation=https://docs.expanso.io/
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart={{ expanso_install_dir }}/expanso-edge run
WorkingDirectory={{ expanso_data_dir }}
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
