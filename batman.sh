#!/bin/bash
########################################
# GLOBALS
APP_NAME="batmans-ansible"
########################################
# we are going to use the ansible.cfg that sits
# beside this file as the ansible config file
WHEREAMI="`dirname \"$BASH_SOURCE\"`" # relative
WHEREAMI="`( cd \"$WHEREAMI\" && pwd )`"   # absolutized and normalized
if [ -z "$WHEREAMI" ]
then
  # error; for some reason, the path is not accessible
  # to the script (e.g. permissions re-evaled after suid)
    >&2 echo "ERROR: Can't properly access this script :("
    exit 1  # fail
fi
########################################
# check for or create local config folder
CONFIG_FOLDER="$HOME/.$APP_NAME"
if ! [ -d "$CONFIG_FOLDER" ]
then
    >&2 echo "INFO: Created config folder at '$CONFIG_FOLDER'"
   mkdir -p "$CONFIG_FOLDER"
fi
########################################
# see which inventories can be found
# caveat emptor: this array hack will break if the
# filenames found by find have spaces in them...
function print_inventory_file {
    file=$1
    content=`cat $1`
    echo `basename $1 | cut -d'_' -f2` "->" `cat $1`
    return $?
}
function list_inventory {
    for f in `find "$CONFIG_FOLDER" -name "inventory_*" -print`
    do
       print_inventory_file $f
    done
    return 0
}
########################################
function add_inventory {
    if [ ".$1" == "." ] || [ ".$2" == "." ]
    then
       >&2 echo "ERROR: Pass a shortname and a folder path for add"
       return 1
    fi
    if ! [ -d "$2" ]
    then
       >&2 echo "ERROR: '$2' is not a valid folder"
       return 1
    fi
    inventory_location="`( cd \"$2\" && pwd )`"
    short_filename="$CONFIG_FOLDER/inventory_$1"
    if [ -e "$short_filename" ]
    then
       >&2 echo "WARNING: $short_filename existed and has now been updated/overwritten"
    fi
    echo "$inventory_location" > "$short_filename"
}
########################################
function rm_inventory {
    if [ ".$1" == "." ]
    then
       >&2 echo "ERROR: Pass a shortname to rm"
       return 1
    fi
    rm "$CONFIG_FOLDER/inventory_$1"
    return $?
}
########################################
function config {
    cfg="$CONFIG_FOLDER/ansible.cfg"

    if [ ".$1" == "." ]; then
	>&2 echo "You need to specify the config file too"
	return 1
    fi

    fullpath="$(cd $(dirname $1); pwd)/$(basename $1)"
    
    if [ -e "$cfg" ]; then
	>&2 echo "ERROR: Found a file (and not a symlink) at '$cfg'. Remove it manually."
	return 1
    fi

    # did we get passed a file that exists?
    if ! [ -e "$1" ]; then
	>&2 echo "ERROR: '$1' is not a regular file."
	return 1
    fi

    # if it's a symlink, just remove it
    [ -h "$cfg" ] && rm "$cfg"

    # create the symlink to the new location
    ln -s "$fullpath" "$cfg"
}
########################################
function load_inventory {
    if [[ ".$1" == "." ]]
    then
	>&2 echo "ERROR: Pass a shortname to load"
	return 1
    fi
    inventory_file="$CONFIG_FOLDER/inventory_$1"
    
    if ! [[ -e "$inventory_file" ]]
    then
	>&2 echo "ERROR: the shortname cannot be found"
	return 1
    fi
    
    inventory_location=`cat $inventory_file`
    inventory_location="`( cd \"$inventory_location\" && pwd )`"
    if ! [[ -d "$inventory_location" ]] || ! [[ -e "$inventory_location/hosts" ]]
    then
	>&2 echo "ERROR: The location pointed to by '$1' ($inventory_location) is not valid"
	>&2 echo "(A valid inventory is in a folder that exists and has a 'hosts' file)"
	return 1
    fi
    export ANSIBLE_ENVIRONMENT="$1"
    export ANSIBLE_VAULT_PASSWORD_FILE="$CONFIG_FOLDER/vault_pw_file_${1}"
    export ANSIBLE_CONFIG="$WHEREAMI/ansible.cfg"
    export ANSIBLE_INVENTORY="$inventory_location/hosts"
    # patch the PS1 to indicate what you are busy with
    if [[ ! "$PS1" == *"\$ANSIBLE_ENVIRONMENT"* ]]
    then
	export PS1="$PS1 (ANSIBLE: \$ANSIBLE_ENVIRONMENT) >> "
    fi
    # create the password file if it doesn't exist
    # this will prompt
    if ! [[ -f "$ANSIBLE_VAULT_PASSWORD_FILE" ]]
    then
	read -s -p "VAULT PASSWORD FOR '$ANSIBLE_ENVIRONMENT' [ENTER]>" VAULT_PW
	echo ""
	echo "$VAULT_PW" > "$ANSIBLE_VAULT_PASSWORD_FILE"
	if [[ ! ".$?" == ".0" ]]
	then
	    >&2 echo "Unable to create the vault password file at '$ANSIBLE_VAULT_PASSWORD_FILE'"
	fi
    fi
}
########################################
case ".$1" in
    ".list")
	list_inventory
	exit $?
	;;
    ".add")
	add_inventory "$2" "$3"
	exit $?
	;;
    ".rm")
	rm_inventory "$2"
	exit $?
	;;
    ".load")
	load_inventory "$2"
	;;
    ".reset")
	load_inventory "$2"
	rm -f "$ANSIBLE_VAULT_PASSWORD_FILE"
	load_inventory "$2"
	;;
    ".config")
	config "$2"
	exit $?
	;;
    ".help")
	cat <<EOF
Utility to help manage different ambient ansible inventories.
---
- list
    Lists all of the local inventories.
- add [short] [path/to/folder]
    Add path/to/folder as a locally tracked inventory.
    Associates the shortname with that inventory.
- rm [short]
    Removes the locally tracked inventory.
- reset [short]
    Resets the vault password for the inventory.
- config [path/to/ansible.cfg]
    Sets the ansible.cfg file for ambient ansible runs.
. load [short]
    THIS COMMAND MUST BE SOURCED INTO THE CURRENT SHELL.
    Makes the inventory ambient to ansible.
EOF
	exit 0
	;;
    ".")
	echo "Specify a command: [ list | add [short] [path/to/folder] | rm [short] | . load [short] | reset [short] ]"
	exit 1
	;;
esac
########################################


