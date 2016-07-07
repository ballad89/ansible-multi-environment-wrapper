# ansible-multi-environment-wrapper

Manage logically similar, but separate ansible inventories using this bash wrapper.

This is a tool for _humans_.

# What

 - Multiple inventories
 - Separate vault passwords
 - Identical playbooks
 - One current/active inventory (so eg `ansible all -m ping` works to different machines depending on which inventory is active)

# How

 - Clone this repo somewhere locally
 - Create `~/bin`
 - Add `~/bin` to your shell `$PATH`
 - `ln -s /path/to/batman.sh $HOME/bin/batman`
 - `chmod +x $HOME/bin/batman`
 - `batman help`
 - `batman add local $HOME/Sources/dev-time-local-vagrant-machine-inventory`
 - `. batman load local` (notice how the PS1 prompt changes to indicate which inventory is active)
 - `ansible all -m setup` etc

