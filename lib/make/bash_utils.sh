#!/bin/bash

# find_files: look through list of directories for presence of all files in
#             given list
# arg 1: dirs (as one string)
# arg 2: file names (as one string)
# return: 0 on success, 1 on failure
function find_files {
  local DIRS=$1
  local FILES=$2
  for dir in $DIRS; do
    FOUND=1
    for file in $FILES; do
      if [ ! -r "$dir/$file" ]; then
        FOUND=0
      fi
    done
    if [ $FOUND -eq 1 ]; then
      FOUND=$dir
      return 0
    fi
  done
  FOUND=
  return 1
}

# find_libs: look through list of directories for presence of all libraries
#            in given list (only library names: no prefix 'lib' and no file
#            extension
# arg 1: dirs (as one string)
# arg 2: file names (as one string)
# return: 0 on success, 1 on failure
function find_libs {
  local DIRS=$1
  local LIBS=$2
  for libext in a so dylib; do
    local FILES=$(echo "$LIBS" | perl -pe 's/(^| )+([^ \n]+)/ lib\2.'"$libext"'/g')
    if find_files "$DIRS" "$FILES"; then
      return 0
    fi
  done
  return 1
}

# test_compile: compile a simple code to check what -I options are needed
#               $1 is the list of include files to use
#               $2 is the list of include directories to test
function test_compile {
  local INCS="$1"
  local INC_DIRS="$2"

  local TMPDIR=$SCRATCH_BUILD/test_compile_tmp$$
  mkdir -p $TMPDIR
  pushd $TMPDIR >/dev/null
  for INC in $INCS ; do
    echo "#include <$INC>"
  done >conftest.c
  cat >>conftest.c <<EOF
  int main(void) { return 0; }
EOF
  local CC_OPTS
  for INCDIR in $INC_DIRS ; do
    CC_OPTS="$CC_OPTS -I$INCDIR"
  done
  ${CC} -c ${CPPFLAGS} ${CFLAGS} ${CC_OPTS} conftest.c &>conftest.log
  RC=$?

  popd >/dev/null
  rm -r $TMPDIR
  return $RC
}

# test_link: link a simple code to check what -L options are needed
#            $1 is the list of librareis to link
#            #2 is the list of linker directories to test
function test_link {
  local LIBS="$1"
  local LIB_DIRS="$2"

  local TMPDIR=$SCRATCH_BUILD/test_link_tmp$$
  mkdir -p $TMPDIR
  pushd $TMPDIR >/dev/null
  cat >>conftest.c <<EOF
  int main(void) { return 0; }
EOF
  local LD_OPTS
  for LIB in $LIBS ; do
    LD_OPTS="$LD_OPTS -l$LIB"
  done
  for LIBDIR in $LIB_DIRS ; do
    LD_OPTS="$LD_OPTS -L$LIBDIR"
  done

  ${CC} ${CPPFLAGS} ${CFLAGS} ${CC_OPTS} conftest.c ${LDFLAGS} ${LD_OPTS} &>conftest.log
  RC=$?

  popd >/dev/null
  rm -r $TMPDIR
  return $RC
}

# strip_incl_dirs: strip system directories from -I finding the minimum list
#                  that lets me compile
function strip_inc_dirs {
  local INCS="$1"
  local INC_DIRS=($2)

  local NUM_INC_DIRS=${#INC_DIRS[*]}
  for i in $(seq 0 $(($NUM_INC_DIRS - 1))) ; do
    local VICTIM=${INC_DIRS[$i]}
    INC_DIRS[$i]=''
    if ! test_compile "$INCS" "${INC_DIRS[*]}" ; then
      # couldn't compile, put directory back
      INC_DIRS[$i]=$VICTIM
    fi
  done

  echo ${INC_DIRS[*]}
}

# strip_lib_dirs: strip system directories from -L finding the minimum list
#                 that lets me link
function strip_lib_dirs {
  local LIBS="$1"
  local LIB_DIRS=($2)

  # check lib directories first, these need to compile and link
  local NUM_LIB_DIRS=${#LIB_DIRS[*]}
  for i in $(seq 0 $(($NUM_LIB_DIRS - 1))) ; do
    local VICTIM=${LIB_DIRS[$i]}
    LIB_DIRS[$i]=''
    if ! test_link "$LIBS" "${LIB_DIRS[*]}" ; then
      # couldn't link, put directory back
      LIB_DIRS[$i]=$VICTIM
    fi
  done

  echo ${LIB_DIRS[*]}
}

# set_make_vars: set variables needed by the Cactus make system, in particular
#                libs, and paths. This takes care of stripping out system paths
#                that shouldn't be in these lists, and guesses PREFIX_DIR to be
#                one level up from the first lib directory
function set_make_vars {
  local PREFIX=$1
  local LIBS=$2
  local LIB_DIRS=$3
  local INC_DIRS=$4
  # For the general ${PREFIX}_DIR we have to guess, since there isn't anything
  # like that in pkg-config
  # take the first directory in LIBS and take off anything past lib\d*
  local DIR=$(echo "$LIB_DIRS" | perl -pe 's/ .*//; s/(.*)\/lib\d*.*/\1/g')
  # If that is empty, assume '/usr'. We just don't know where
  # the library is, and we don't need to. But we need to set ${PREFIX}_DIR to
  # something to indicate a find
  : "${DIR:=/usr}"

  local STRIPPED_LIB_DIRS=$("${CCTK_HOME}/lib/sbin/strip-libdirs.sh" "$LIB_DIRS")
  local STRIPPED_INC_DIRS=$("${CCTK_HOME}/lib/sbin/strip-incdirs.sh" "$INC_DIRS")

  eval "${PREFIX}_DIR=\"$DIR\""
  eval "${PREFIX}_LIBS=\"$LIBS\""
  eval "${PREFIX}_RAW_LIB_DIRS=\"$LIB_DIRS\""
  eval "${PREFIX}_RAW_INC_DIRS=\"$INC_DIRS\""
  eval "${PREFIX}_LIB_DIRS=\"$STRIPPED_LIB_DIRS\""
  eval "${PREFIX}_INC_DIRS=\"$STRIPPED_INC_DIRS\""
}

# set_make_vars2: set variables needed by the Cactus make system, in particular
#                 libs, and paths. This takes care of stripping out system paths
#                 that shouldn't be in these lists, and guesses PREFIX_DIR to be
#                 one level up from the first lib directory
function set_make_vars2 {
  local PREFIX=$1
  local LIBS=$2
  local INCS=$3
  local LIB_DIRS=$4
  local INC_DIRS=$5
  # For the general ${PREFIX}_DIR we have to guess, since there isn't anything
  # like that in pkg-config
  # take the first directory in LIBS and take off anything past lib\d*
  local DIR=$(echo "$LIB_DIRS" | perl -pe 's/ .*//; s/(.*)\/lib\d*.*/\1/g')
  # If that is empty, assume '/usr'. We just don't know where
  # the library is, and we don't need to. But we need to set ${PREFIX}_DIR to
  # something to indicate a find
  : "${DIR:=/usr}"

  local STRIPPED_INC_DIRS=$(strip_inc_dirs "$INCS" "$INC_DIRS")
  local STRIPPED_LIB_DIRS=$(strip_lib_dirs "$LIBS" "$LIB_DIRS")

  eval "${PREFIX}_DIR=\"$DIR\""
  eval "${PREFIX}_LIBS=\"$LIBS\""
  eval "${PREFIX}_RAW_LIB_DIRS=\"$LIB_DIRS\""
  eval "${PREFIX}_RAW_INC_DIRS=\"$INC_DIRS\""
  eval "${PREFIX}_LIB_DIRS=\"$STRIPPED_LIB_DIRS\""
  eval "${PREFIX}_INC_DIRS=\"$STRIPPED_INC_DIRS\""
}

# pkg_config: use pkg-config to configure a library
# arg 1: Cactus env variable prefix (e.g. HDF5)
# arg 2: library name
# arg 3: minimum version
function pkg_config {
  local PREFIX=$1
  local LIBNAME=$2
  local MINVERSION=$3
  local PKGCONFIG=pkg-config
  local STATIC="--static"
  $PKGCONFIG --version >/dev/null 2>&1 || return 0
  if [ -z "$MINVERSION" ]; then
    $PKGCONFIG --exists "$LIBNAME" > /dev/null 2>&1 || return 0
  else
    $PKGCONFIG --atleast-version="$MINVERSION" "$LIBNAME" > /dev/null 2>&1 || return 0
  fi

  # NOTE: This breaks if pkg-config returns quotes strings, i.e., path names
  #       with strings in them. It doesn't seems to happen in practice.
  #       If it does: let us know what pkg-config prints in that case, and we
  #       can try to fix it.
  local INC_DIRS=$($PKGCONFIG --cflags-only-I "$STATIC" "$LIBNAME" | perl -pe 's/(^| )+-I/\1/g')
  local LIB_DIRS=$($PKGCONFIG --libs-only-L   "$STATIC" "$LIBNAME" | perl -pe 's/(^| )+-L/\1/g')
  # pkg-config sometimes returns incorrect -l options with the full path of the
  # library file instead of just the library name. So we look for any library
  # files that contain a / (by testing if ${lib} changes when we remove a
  # trailing `/*` pattern) and if so add both a the library name itself to LIBS
  # and the directory the library is in to LIB_DIRS
  local     LIBS=""
  local ALLLIBS=$($PKGCONFIG --libs-only-l   "$STATIC" "$LIBNAME" | perl -pe 's/(^| )+-l/\1/g')
  local lib
  for lib in $ALLLIBS; do
    if [ "${lib%/*}" != "$lib" ] ; then
      LIB_DIRS="$LIB_DIRS ${lib%/*}"
      lib=${lib##*/lib}
      lib=${lib%.*}
    fi
    LIBS="$LIBS $lib"
  done

  set_make_vars "$PREFIX" "$LIBS" "$LIB_DIRS" "$INC_DIRS"

  PKG_CONFIG_SUCCESS=yes
  return 0
}

# pkg_config2: use pkg-config to configure a library
# arg 1: Cactus env variable prefix (e.g. HDF5)
# arg 2: library name
# arg 3: minimum version
# arg 4: include files to test -I path with
function pkg_config2 {
  local PREFIX=$1
  local LIBNAME=$2
  local MINVERSION=$3
  local INCS="$4"
  local PKGCONFIG=pkg-config
  local STATIC="--static"
  $PKGCONFIG --version >/dev/null 2>&1 || return 0
  if [ -z "$MINVERSION" ]; then
    $PKGCONFIG --exists "$LIBNAME" > /dev/null 2>&1 || return 0
  else
    $PKGCONFIG --atleast-version="$MINVERSION" "$LIBNAME" > /dev/null 2>&1 || return 0
  fi
  # NOTE: This breaks if pkg-config returns quotes strings, i.e., path names
  #       with strings in them. It doesn't seems to happen in practice.
  #       If it does: let us know what pkg-config prints in that case, and we
  #       can try to fix it.
  local     LIBS=$($PKGCONFIG --libs-only-l   "$STATIC" "$LIBNAME" | perl -pe 's/(^| )+-l/\1/g')
  local LIB_DIRS=$($PKGCONFIG --libs-only-L   "$STATIC" "$LIBNAME" | perl -pe 's/(^| )+-L/\1/g')
  local INC_DIRS=$($PKGCONFIG --cflags-only-I "$STATIC" "$LIBNAME" | perl -pe 's/(^| )+-I/\1/g')

  set_make_vars2 "$PREFIX" "$LIBS" "$INCS" "$LIB_DIRS" "$INC_DIRS"

  PKG_CONFIG_SUCCESS=yes
  return 0
}

# find_standardlib: find a library installed in the 'standard' way
# arg1: Cactus env variable prefix (e.g. HDF5)
# arg2: library name
# arg3: required libs (as one string)
# arg4: required header file names (as one string)
# return: 0 on success, 1 on failure
function find_standardlib {
  local PREFIX=$1
  local LIBNAME=$2
  local LIBS=$3
  local INCS=$4
  local GUESS=$5
  local INCFILES=$(echo "$INCS" | perl -pe 's/(^| )+([^ \n]+)/ include\/\2/g')

  # multi-arch file layouts without pkg-config
  MACHINE=${MACHINE:=`gcc -dumpmachine 2>/dev/null`} || true
  if [ -n "${MACHINE}" ]; then
    MACHINE="lib/${MACHINE}"
  fi
  # standard paths

  local DIRS="$GUESS /usr /usr/local /usr/local/packages /usr/local/apps /opt /opt/local /opt/homebrew $HOME c:/packages"
  local ALLDIRS=$(echo "$DIRS" | perl -pe 's/([^ \n]+)/\1\/'"$LIBNAME"' \1/g')
  # for each of these dirs, check if all necessary files are there
  for dir in $ALLDIRS; do
    local FINCFILES=$(echo "$INCFILES" | perl -pe 's|(^\| )+([^ \n]+)| '"$dir"'/\2|g')
    for ldir in . lib64 lib "${MACHINE}"; do
      # different possibilities for library names
      for libext in a so dylib; do
        local LIBFILES=$(echo "$LIBS" | perl -pe 's|(^\| )+([^ \n]+)| '"$dir/$ldir"'/lib\2.'$libext'|g')
        local FILES="$LIBFILES $FINCFILES"
        FOUND=1
        for file in $FILES; do
          if [ ! -r "$file" ]; then
            FOUND=0
            break
          fi
        done
        if [ $FOUND -eq 1 ]; then
          FOUND=$dir
          set_make_vars2 "$PREFIX" "$LIBS" "$INCS" "$dir/$ldir" "$dir/include"
          return 0
        fi
      done
    done
  done
  FOUND=
  return 1
}

# find_lib: find a library using either pkg-config or a hand-grown search
#           not all arguments work with both searches though (e.g. MINVERSION)
function find_lib {
  local PREFIX=$1
  local LIBNAME=$2
  local STATIC=$3
  local MINVERSION=$4
  local LIBS=$5
  local INCS=$6
  local GUESS=$7

  if [ -z "$GUESS" ]; then
    echo "BEGIN MESSAGE"
    echo "$PREFIX selected, but ${PREFIX}_DIR not set. Checking pkg-config ..."
    echo "END MESSAGE"
    pkg_config2 "$PREFIX" "$LIBNAME" "$MINVERSION" "$INCS"
    if [ -n "$PKG_CONFIG_SUCCESS" ]; then
      echo "BEGIN MESSAGE"
      eval "echo \"$PREFIX found: \"\${${PREFIX}_DIR}"
      echo "END MESSAGE"
    else
      echo "BEGIN MESSAGE"
      echo "$PREFIX not found. Checking standard paths ..."
      echo "END MESSAGE"
      if find_standardlib "$PREFIX" "$LIBNAME" "$LIBS" "$INCS" "$GUESS"; then
        echo "BEGIN MESSAGE"
        echo "$PREFIX found."
        echo "END MESSAGE"
      else
        echo "BEGIN MESSAGE"
        echo "$PREFIX not found."
        echo "END MESSAGE"
      fi
    fi
  else
    echo "BEGIN MESSAGE"
    echo "$PREFIX selected, and ${GUESS} selected."
    echo "END MESSAGE"
    if find_standardlib "$PREFIX" "$LIBNAME" "$LIBS" "$INCS" "$GUESS"; then
      echo "BEGIN MESSAGE"
      echo "$PREFIX found."
      echo "END MESSAGE"
    else
      echo "BEGIN ERROR"
      echo "$PREFIX not found at ${GUESS}."
      echo "Either the library is not there or has a non-standard "
      echo "layout, so that you need to set ${PREFIX}_LIB_DIRS and/or ${PREFIX}_INC_DIRS."
      echo "END ERROR"
      return 1
    fi
  fi
}

# check_tools: A function to provide checks for presence of common tools
#              needed by many library installations (tar, patch, ...)
function check_tools {
  for tool in $1; do
    case $tool in
      "tar")
        if [ "x$TAR" = x ] ; then
            echo 'BEGIN ERROR'
            echo 'Could not find tar command.'
            echo 'Please make sure that the (GNU) tar command is present,'
            echo 'and that the TAR variable is set to its location.'
            echo 'END ERROR'
            return 1
        fi;;
      "patch")
         if [ "x$PATCH" = x ] ; then
             echo 'BEGIN ERROR'
             echo 'Could not find patch command.'
             echo 'Please make sure that the patch command is present,'
             echo 'and that the PATCH variable is set to its location.'
             echo 'END ERROR'
             return 1
         fi;;
      *)
          echo "Unknown tool $tool"
          return 1;;
    esac
  done
}
