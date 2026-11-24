# Remote desktop
#
# Switch a Linux dev box's desktop between Chrome Remote Desktop and RDP
# carried by a Microsoft dev tunnel, or turn both off. Only one can run at a
# time, and nothing starts at boot. The tunnel's name lives in
# ~/.config/remote-desktop/config, outside the repository; see
# scripts/remote-desktop/config.example.
#
# Kept in a file of its own so any repository can load it with `import?` and
# run `just rdp windows`, while mark-house-style's own justfile loads it for
# `just -g`. The short name is rdp, not rd, which Quill Medical uses for
# review-diff. Paths are taken from this file's own folder.
remote_desktop_scripts := source_directory() / ".." / "scripts" / "remote-desktop"


alias rdp := remote-desktop
# Switch the box's remote desktop: google, windows, off, kill or status (nothing starts at boot)
[no-cd]
remote-desktop mode="status":
    sudo /usr/local/sbin/remote-desktop "{{mode}}"


alias rdi := remote-desktop-install
# Install the remote desktop switch, its sudo rule and the tunnel service (run again after they change)
[no-cd]
remote-desktop-install:
    sudo bash "{{remote_desktop_scripts}}/install.sh"


alias rdtune := remote-desktop-tune
# Tune RDP's H.264 picture: cap per screen in kbit/s (0 for none) and frames a second; reconnect after
[no-cd]
remote-desktop-tune bitrate="10000" fps="30":
    sudo bash "{{remote_desktop_scripts}}/xrdp-tune.sh" "{{bitrate}}" "{{fps}}"


alias rdt := remote-desktop-test
# Run the remote desktop scripts' tests
[no-cd]
remote-desktop-test:
    bats "{{remote_desktop_scripts}}/tests"
