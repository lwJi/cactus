check_cmd () {
	log "Checking if $1 command exists"
	if command -v $2 2> /dev/null > /dev/null
	then
		ok;  return 0;
	else
		fail; return 1;
	fi
}

check_dir () {
	log "Checking if $1 directory exists";
	if [ -d "$2" ]
	then
		ok;     return 0;
	else
		yellow_ok;   return 1;
	fi
}

check_file () {
	log "Checking if $1 file exists";
	if [ -f "$2" ]
	then
		ok;     return 0;
	else
		yellow_ok;   return 1;
	fi
}

check_var () {
	log "Checking if $1 variable is set";
	if [ -z "$2" ]
	then
		yellow_ok;     return 1;
	else
		ok;       return 0;
	fi
}
