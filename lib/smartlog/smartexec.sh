set +e

s_ex () {
	log "$1";
	if $2 2>> error.log 1>> output.log
	then
		ok;   return 0;
	else
		fail; return 1;
	fi
}

s_mv () {
	log "Moving $1 to $2"; echo ""
	if check_file "$1" "$3"
	then
		if check_file "$2" "$4"
		then
			warn "Overwriting $2"
			mv $3 $4
			return 0;
		elif check_dir "$2" "$4"
		then
			if check_file "within $2 directory the $1" "$2/$1"
			then
				warn "Overwriting $2"
				mv $3 $4
				return 0;
			elif check_dir "within $2 directory the $1" "$2/$1"
			then
				warn "Directory by same name exists"
				mv $3 $4
				return 0;
			fi
			log "Copying source '$1' to destination '$2'"
			cp $3 $4 2> /dev/null > /dev/null
			ok
			return 0;
		else	
			log "Moving source '$1' to destination '$2'"
			mv $3 $4
			ok
			return 0;
		fi
	elif check_dir "$1" "$3"
	then
		if check_file "$2" "$4"
		then
			alert "Cannot move directory into file"
			return 1;
		elif check_dir "$2" "$4"
		then
			if check_file "within $2 directory the $1" "$2/$1"
			then
				warn "Overwriting $2"
				mv $3 $4
				return 0;
			elif check_dir "within $2 directory the $1" "$2/$1"
			then
				alert "Cannot move directory into file"
				return 1;
			fi
			log "Copying source '$1' to destination '$2'"
			cp $3 $4
			ok
			return 0;
		else
			log "Copying source '$1' to destination '$2'"
			cp $3 $4
			ok
			return 0;
		fi
	else
		alert "$1 file/directory does not exist"
	fi
}


s_cp () {
	if check_file "$1" "$3"
	then
		if check_file "$2" "$4"
		then
			warn "Overwriting $2"
			cp $3 $4
			return 0;
		elif check_dir "$2" "$4"
		then
			if check_file "within $2 directory the $1" "$2/$1"
			then
				warn "Overwriting $2"
				cp $3 $4
				return 0;
			elif check_dir "within $2 directory the $1" "$2/$1"
			then
				warn "Directory by same name exists"
				cp $3 $4
				return 1;
			fi
			log "Copying source '$1' to destination '$2'"
			cp $3 $4 2> /dev/null > /dev/null
			ok
			return 0;
		else
			log "Copying source '$1' to destination '$2'"
			cp $3 $4
			ok
			return 0;
		fi
	elif check_dir "$1" "$3"
	then
		if check_file "$2" "$4"
		then
			alert "Cannot copy directory into file"
			return 1;
		elif check_dir "$2" "$4"
		then
			if check_file "within $2 directory the $1" "$2/$1"
			then
				warn "Overwriting $2"
				cp $3 $4
				return 0;
			elif check_dir "within $2 directory the $1" "$2/$1"
			then
				alert "Cannot copy directory into file"
				return 1;
			fi
			log "Copying source '$1' to destination '$2'"
			cp $3 $4
			ok
			return 0;
		else
			log "Copying source '$1' to destination '$2'"
			cp $3 $4
			ok
			return 0;
		fi
	else
		alert "$1 file/directory does not exist"
	fi
}

s_cd () {
	if ! check_dir "$1" "$2"
	then
		if check_file "$1" "$2" 
		then
			alert "$1 'directory' is actually a file"
			return 1;
		else
			alert "$1 file/directory does not exist"
			return 1;
		fi
	else
		cd $2
		return 0;
	fi
}
