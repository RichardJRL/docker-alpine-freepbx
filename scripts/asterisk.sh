#!/bin/bash

############################################################
# Major Software Component Versions
############################################################

# Open Settlement Protocol ToolKit (OSPTK)
# Version list: https://sourceforge.net/p/osp-toolkit/code/HEAD/tree/branches/
OSPTK_VERSION='4.14'
INSTALL_OSPTK=''

# Corosync
# Version list: https://github.com/corosync/corosync/wiki/Releases
# Version list: https://github.com/corosync/corosync/releases
COROSYNC_VERSION='3.1.6'
INSTALL_COROSYNC=''
# LibQB (a dependency of Corosync)
# Version list: https://github.com/ClusterLabs/libqb/releases
LIBQB_VERSION='2.0.4'
# Kronosnet (a dependency of Corosync)
# Version list: https://kronosnet.org/releases/
KRONOSNET_VERSION='1.23'

# Codec2
# Version list: https://github.com/drowe67/codec2/releases
CODEC2_VERSION='1.0.3'
INSTALL_CODEC2=''

# Hoard - DOES NOT COMPILE ON ALPINE
# Version list: https://github.com/emeryberger/Hoard/releases
HOARD_VERSION='3.13'
INSTALL_HOARD=''

# Iksemel
# An old project hosted on Google Code. FSF link now redirects to:
# https://github.com/meduketto/iksemel
# It hasn't been updated in 10 years and fails to compile.
# Debian have taken the final release of the code above and patched to keep it working
# https://packages.debian.org/bookworm/libiksemel-dev
# Some more developed forks are:
# last updated 13/12/19, 36 commits: https://github.com/timothytylee/iksemel-1.4
# last updated 13/06/18, 65 commits: https://github.com/holme-r/iksemel
# last updated 21/12/20, 161 commits: https://github.com/Zaryob/iksemel
#
# IKSEMEL_FORK value can be 'debian' OR 'timothytylee' OR 'holme-r' OR 'Zaryob' (the name of the github user who created the fork)
# IKSEMEL_VERSION can be chosen from the following. Get it right, there's no checking the version number exists for the chosen fork later on.
# debian: Releases: 1.4-3
# timothytylee: Releases: 1.4.2 - 1.4.1
# holme-r: Releases: 1.5.1.3 - 1.5.1.2 - 1.5.1.1 - 1.5.1
# Zaryob: Releases: 1.0
# 'debian' would be RECOMMENDED for greatest trustworthiness, but it doesn't work. homlme-r works well. 
IKSEMEL_FORK='holme-r'
IKSEMEL_VERSION='1.5.1.3'
INSTALL_IKSEMEL=''

# OpenR2
# Version list: https://github.com/moises-silva/openr2/tags
OPENR2_VERSION='1.3.2'
INSTALL_OPENR2=''

# iODBC
# Version list: https://github.com/moises-silva/openr2/tags
IODBC_VERSION='3.52.15'
INSTALL_IOBDC=''

# SS7
# Version list: http://downloads.asterisk.org/pub/telephony/libss7/
SS7_VERSION='2.0.1'
INSTALL_SS7=''

# SoX
# NB: Alpine provides SoX package but I have no information on which codecs it supports.
# TODO: Check which codecs Alpine's sox package supports
# Version list: https://sourceforge.net/projects/sox/files/sox/
# Version 14.4.2 released on 2015-02-22 but development has continued since albeit without any further releases tagged on sourceforge
# Development appears to continue and the mailing list remains active
# TODO: Cloning the repo amd build from the current development head?
SOX_VERSION='14.4.2'
INSTALL_SOX=''
# TwoLame (A dependency of SoX)
# Version list: 
TWOLAME_VERSION='0.4.0'
# Libube (A dependency of libssp which itself is a dependency of SoX)
# Version list: https://github.com/pgarner/libube/tags
LIBUBE_VERSION='1.0.1'
# Libssp (A dependency of SoX)
# Version list: https://github.com/idiap/libssp/tags
LIBSSP_VERSION='1.0'

# Asterisk PBX
# Version list: http://downloads.asterisk.org/pub/telephony/asterisk/
# Version list: http://downloads.asterisk.org/pub/telephony/asterisk/releases/
# Version list: https://github.com/asterisk/asterisk/tags 
ASTERISK_VERSION='19.0.0'
INSTALL_ASTERISK=''

# FreePBX
# Version list: 
FREEPBX_VERSION='16.0'

############################################################
# Other global variables
############################################################
DOWNLOAD_DIR='/config/downloads'
BUILD_ESSENTIALS='build-base gcc git make'
PARALLEL_MAKE=''
PARALLEL_CMAKE=''

############################################################
# Bash functions
############################################################

# get_source_archive ARCHIVE_URL LOCAL_PATH SOURCE_DIR
# ARCHIVE_URL = http(s) URL where the source code archive is located
# LOCAL_PATH = full path including filename for the downloaded the source code archive
# SOURCE_DIR = directory into which the contents of the downloaded source code archive are to be extracted
#
# Assumes archive is a .tar.gz file

get_source_archive () {
  ARCHIVE_URL="$1"
  LOCAL_PATH="$2"
  SOURCE_DIR="$3"
  if [[ ! -f "$LOCAL_PATH" ]]
  then
    DOWNLOAD_STATUS=1
    DOWNLOAD_ATTEMPTS=0
    while [[ DOWNLOAD_STATUS -ne 0 && DOWNLOAD_ATTEMPTS -lt 10 ]]
    do
      wget -c -O "$LOCAL_PATH" "$ARCHIVE_URL"
      DOWNLOAD_STATUS=$?
      ((DOWNLOAD_ATTEMPTS++))
      echo "$DOWNLOAD_ATTEMPTS attempt(s) made to download $ARCHIVE_URL"
    done
    if [[ DOWNLOAD_STATUS -ne 0 ]]
    then
      echo "Failed to properly download the required dependency from $ARCHIVE_URL after $DOWNLOAD_ATTEMPTS attempts, exiting..."
      rm "$LOCAL_PATH"
      exit 1
    else
      echo "Download of $ARCHIVE_URL successful"
    fi
  fi
  if [[ -f "$LOCAL_PATH" ]]
  then
    # remove local source directory if it exists to ensure a completely clean version of the archive created
    if [[ -d $SOURCE_DIR ]]
    then
      rm -r $SOURCE_DIR
    fi
    # create new, empty source directory
    mkdir -p "$SOURCE_DIR"
    cd "$SOURCE_DIR" || exit
    # extract the archive
    if [[ "$LOCAL_PATH" =~ gz$ ]]
    then
      tar -x -z -v -f "$LOCAL_PATH" --strip 1 -C "$SOURCE_DIR"
      return $?
    elif [[ "$LOCAL_PATH" =~ xz$ ]]
    then
      tar -x -J -v -f "$LOCAL_PATH" --strip 1 -C "$SOURCE_DIR"
      return $?
    else
      echo "Incompatible archive format for $LOCAL_PATH . Cannot extract it to $SOURCE_DIR . Exiting..."
      return 1
    fi
  else
    echo "Could not find the required file $LOCAL_PATH . Exiting..."
    return 2
  fi
}


############################################################
# Pre-installation tasks
############################################################
# Parse command line arguments
for arg in "$@"
do
  if [[ "$arg" =~ ^--parallel= ]]
  then
    echo "Using parallel compilation flag for make/cmake..."
    NUM_PARALLEL_JOBS=$(echo $arg | sed 's/--parallel=//')
    # CHECK_POSITIVE_INTEGER=$(echo $NUM_PARALLEL_JOBS | sed -E 's/[0-9]+//')
    echo "NUM_PARALLEL_JOBS is $NUM_PARALLEL_JOBS"
    echo "CHECK_POSITIVE_INTEGER is '$CHECK_POSITIVE_INTEGER'"
    if [[ $NUM_PARALLEL_JOBS =~ ^[0-9]+$ ]]
    then
      PARALLEL_MAKE="-j $NUM_PARALLEL_JOBS"
      PARALLEL_CMAKE="--parallel $NUM_PARALLEL_JOBS"
      echo "Using parallel compilation flag for make/cmake to run $NUM_PARALLEL_JOBS concurrent compile tasks..."
    else
      echo "Error: --parallel= argument must be followed by a positive integer. The value found is '$NUM_PARALLEL_JOBS'. Exiting..."
      exit 1
    fi
  elif [[ "$arg" =~ ^--install-osptk$ ]]
  then
    echo "Selected OSPTK for installation..."
    INSTALL_OSPTK='true'
  elif [[ "$arg" =~ ^--install-corosync$ ]]
  then
    echo "Selected Corosync for installation..."
    INSTALL_COROSYNC='true'
  elif [[ "$arg" =~ ^--install-codec2$ ]]
  then
    echo "Selected Codec2 for installation..."
    INSTALL_CODEC2='true'
  elif [[ "$arg" =~ ^--install-hoard$ ]]
  then
    echo "Selected Hoard for installation..."
    INSTALL_HOARD='true'
  elif [[ "$arg" =~ ^--install-iksemel$ ]]
  then
    echo "Selected Iksemel for installation..."
    INSTALL_IKSEMEL='true'
  elif [[ "$arg" =~ ^--install-openr2$ ]]
  then
    echo "Selected OpenR2 for installation..."
    INSTALL_OPENR2='true'
  elif [[ "$arg" =~ ^--install-iodbc$ ]]
  then
    echo "Selected iODBC for installation..."
    INSTALL_IOBDC='true'
  elif [[ "$arg" =~ ^--install-ss7$ ]]
  then
    echo "Selected ss7 for installation..."
    INSTALL_SS7='true'
  elif [[ "$arg" =~ ^--install-sox$ ]]
  then
    echo "Selected SoX for installation..."
    INSTALL_SOX='true'
  elif [[ "$arg" =~ ^--install-asterisk$ ]]
  then
    echo "Selected Asterisk for installation..."
    INSTALL_ASTERISK='true'
  elif [[ "$arg" =~ ^--install-all$ ]]
  then
    echo "Selected all dependencies for installation..."
    INSTALL_ALL='true'
  else
    echo "Unknown argument '$arg'"
    exit 1
  fi
done

# Create a directory for downloaded source archives
if ! [[ -d "$DOWNLOAD_DIR" ]]
then
  mkdir "$DOWNLOAD_DIR"
fi

# apk update
# apk upgrade
# install bare-minimum build essentials
apk add $BUILD_ESSENTIALS
echo "$NUM_PARALLEL_JOBS" > /scripts/parallel_value.txt
echo $PARALLEL_MAKE >> /scripts/parallel_value.txt
echo $PARALLEL_CMAKE >> /scripts/parallel_value.txt

############################################################
# Install, build and configure asterisk and its dependencies
############################################################

####################
# OSP Toolkit
####################
if [[ "$INSTALL_OSPTK" =~ true || "$INSTALL_ALL" =~ true ]]
  then
  # Get OSPTK
  OSPTK_DOWNLOAD_URL="https://downloads.sourceforge.net/project/osp-toolkit/OSPToolkit-$OSPTK_VERSION.0.tar.gz"
  OSPTK_LOCAL_ARCHIVE="$DOWNLOAD_DIR/osptoolkit-v$OSPTK_VERSION.0.tar.gz"
  OSPTK_SRC_DIR='/usr/src/osptk'
  
  mkdir -p "$OSPTK_SRC_DIR"
  cd "$OSPTK_SRC_DIR" || exit
  
  # wget only works for OSPTK_VERSION<=4.13 as the sourceforge repository 
  # download section has not been updated and no archive exists for v4.14
  # Also, bash cannot compare decimals, only inegers.
  INTEGER_OSPTK_VERSION=$(echo $OSPTK_VERSION | sed 's/\.//g')
  if [[ $INTEGER_OSPTK_VERSION -le 413 ]]
  then
    get_source_archive "$OSPTK_DOWNLOAD_URL" "$OSPTK_LOCAL_ARCHIVE" "$OSPTK_SRC_DIR"
  else
    if [[ ! -f $OSPTK_LOCAL_ARCHIVE ]]
    then
      # Install required download tools
      apk add git-svn
      # Clone repo
      git svn clone -T "branches/$OSPTK_VERSION" https://svn.code.sf.net/p/osp-toolkit/code/ "$OSPTK_SRC_DIR"
      # Create archive of repo in download dir to avoid time-consuming re-cloning of the repository.
      # NB: whitespace between '/usr/src' and 'osptk' is deliberate. It creates an archive whose (directory/filesystem)
      # root is a project-named directory, the same as for those other depenencies that are downloaded from github.  
      tar czvf $OSPTK_LOCAL_ARCHIVE -C /usr/src/ osptk
    else
      tar xzvf "$OSPTK_LOCAL_ARCHIVE" --strip 1 -C "$OSPTK_SRC_DIR"
    fi
  fi
  
  # Install required development packages
  apk add libc-dev openssl-dev openssl

  # Build OSPTK
  cd "$OSPTK_SRC_DIR/src" || exit
  # Change from _GNU_SOURCE to _XOPEN_SOURCE to prevent compiler error with gethostbyname_r(...) function
  # This was working but now it isn't, remove any mention of _???_SOURCE from gcc compiler options and it works
  # sed -i 's/_GNU_SOURCE/_XOPEN_SOURCE/' Makefile
  sed -i 's/-D_GNU_SOURCE//' Makefile
  make clean
  make $PARALLEL_MAKE build
  make install

  # Build OSPTK enrollment utility
  cd "$OSPTK_SRC_DIR/enroll" || exit
  make clean
  make $PARALLEL_MAKE linux

  # Make the contents of the $OSPTK_SRC_DIR/bin directory accessible
  # Trying to adhere to Ubuntu conventions for its 'osptoolkit' package
  # Files for /usr/lib/osp
  install -d /usr/lib/osp
  cp "$OSPTK_SRC_DIR/bin/enroll" /usr/lib/osp/
  cp "$OSPTK_SRC_DIR/bin/enroll.sh" /usr/lib/osp/
  ln -s /usr/lib/osp/enroll.sh /usr/local/bin/ospenroll

  # Edit the enroll.sh script to point to the new locations of the .rnd, openssl.cnf files and the enroll binary
  #ADD ospdir=/usr/lib/osp ADD cnfdir=/etc/osp
  sed -i '/OPENSSL_CONF=/i \
  ospdir=/usr/lib/osp\
  cnfdir=/etc/osp' /usr/lib/osp/enroll.sh
  #EDIT OPENSSL_CONF=./openssl.cnf -->> OPENSSL_CONF=$cnfdir/openssl.cnf
  sed -i 's/OPENSSL_CONF=\./OPENSSL_CONF=$cnfdir/' /usr/lib/osp/enroll.sh
  #EDIT RANDFILE=./.rnd -->> RANDFILE=$cnfdir/.rnd
  # Although RANDFILE does not appear to be used. Location of .rnd appears hardcoded instead.)
  sed -i 's/RANDFILE=\.\/\.rnd/RANDFILE=$cnfdir\/random.seed/' /usr/lib/osp/enroll.sh
  # AND modify every call of enroll (there are 3) such; enroll... -->> $ospdir/enroll ...
  sed -i 's/^enroll/\$ospdir\/enroll/g' /usr/lib/osp/enroll.sh

  # Files for /etc/osp
  install -d /etc/osp
  cp "$OSPTK_SRC_DIR/bin/openssl.cnf" /etc/osp/
  # The location of .rnd is hardcoded in 'ospopenssl.c' to be the same directory as the compiled programs.
  # To survive container re-creation intact, it is placed in /etc/osp and a symlink to it placed in /usr/lib/osp
  if ! [[ -f /etc/osp/random.seed ]]
  then
    dd bs=128 count=1 if=/dev/urandom of=/etc/osp/random.seed
    printf \
  "\n\
  This file must *begin* with 128 bits of true randomness for seeding\n\
  the pseudo-random number generator engine used by the OSP Toolkit.\n\
  \n\
  ALL RANDOMNESS MUST BE ABOVE THIS TEXT ON THE FIRST LINE OF THE FILE!\n\
  \n\
  The first time this container was created, it was seeded using the command:\n\
  dd bs=128 count=1 if=/dev/urandom of=/etc/osp/random.seed\n" >> /etc/osp/random.seed
    chmod 440 /etc/osp/random.seed
  fi
  ln -s /etc/osp/random.seed /usr/lib/osp/.rnd

  # Make the programs in the test directory
  cd "$OSPTK_SRC_DIR/test/" || exit
  apk add g++
  make clean
  make $PARALLEL_MAKE linux
  cp "$OSPTK_SRC_DIR/bin/test_app" /usr/lib/osp/
  ln -s /usr/lib/osp/test_app /usr/local/bin/osptest
  cp "$OSPTK_SRC_DIR/bin/test.cfg" /etc/osp/
  # TODO: work out if the test.cfg file is still accessible to the test executable now they are in different dirs
  # TODO: ^^ If not, put it in the same dir as the test binary and symlink it to /etc/osp

  # Inspect results of installation of the OSP Toolkit
  echo "Contents of /usr/local/include/osp"
  ls -l /usr/local/include/osp
  echo "Contents of /usr/local/lib"
  ls -l /usr/local/lib
  echo "Contents of /usr/local/bin"
  ls -al /usr/local/bin
  echo "Contents of /usr/lib/osp"
  ls -al /usr/lib/osp/
  echo "Contents of /etc/osp"
  ls -al /etc/osp/
  # Temporary exit to assess installation of OSPTK

  # TODO: Remove OSPTK source directory if no longer needed
  # TODO: Check if still needed by asterisk
  #rm -r "$OSPTK_SRC_DIR"
fi

####################
# Corosync
####################

if [[ "$INSTALL_COROSYNC" =~ true || "$INSTALL_ALL" =~ true ]]
  then
  Install the Corosync dependency LibQB
  LIBQB_DOWNLOAD_URL="https://github.com/ClusterLabs/libqb/archive/refs/tags/v$LIBQB_VERSION.tar.gz"
  LIBQB_LOCAL_ARCHIVE="$DOWNLOAD_DIR/libqb-v$LIBQB_VERSION.tar.gz"
  LIBQB_SRC_DIR='/usr/src/libqb'
  
  mkdir -p "$LIBQB_SRC_DIR"
  cd "$LIBQB_SRC_DIR" || exit
  
  get_source_archive "$LIBQB_DOWNLOAD_URL" "$LIBQB_LOCAL_ARCHIVE" "$LIBQB_SRC_DIR"

  # Install required build tools
  apk add autoconf automake build-base libtool libxml2-dev pkgconf
  # Install required development packages (optional; for tests)
  #apk add check-dev 
  # Install required development packages (optional; for glib example code)
  #apk add glib-dev
  # Install required development packages (optional; for documentation)
  #apk add doxygen graphviz 

  # Build libpq
  # autogen.sh not needed if installing from tarball - NOT TRUE, configure does not exist until autogen.sh is run
  ./autogen.sh
  ./configure
  make $PARALLEL_MAKE 
  make install

  # Install the Corosync dependency Kronosnet
  KRONOSNET_DOWNLOAD_URL="https://kronosnet.org/releases/kronosnet-$KRONOSNET_VERSION.tar.gz"
  KRONOSNET_LOCAL_ARCHIVE="$DOWNLOAD_DIR/kronosnet-v$KRONOSNET_VERSION.tar.gz"
  KRONOSNET_SRC_DIR='/usr/src/kronosnet'

  mkdir -p "$KRONOSNET_SRC_DIR"
  cd "$KRONOSNET_SRC_DIR" || exit

  get_source_archive "$KRONOSNET_DOWNLOAD_URL" "$KRONOSNET_LOCAL_ARCHIVE" "$KRONOSNET_SRC_DIR"

  # Install required development packages
  apk add bzip2-dev doxygen libnl3-dev lksctp-tools-dev lzo-dev lz4-dev openssl-dev nss-dev xz-dev zlib-dev zstd-dev 

  # Build Kronosnet
  # NB: autogen.sh not needed if installing from tarball - This IS true, configure already exists.
  #./autogen.sh
  ./configure
  make $PARALLEL_MAKE 
  make install

  # Get Corosync
  COROSYNC_DOWNLOAD_URL="https://github.com/corosync/corosync/archive/refs/tags/v$COROSYNC_VERSION.tar.gz"
  COROSYNC_LOCAL_ARCHIVE="$DOWNLOAD_DIR/corosync-v$COROSYNC_VERSION.tar.gz"
  COROSYNC_SRC_DIR='/usr/src/corosync'
  
  mkdir -p "$COROSYNC_SRC_DIR"
  cd "$COROSYNC_SRC_DIR" || exit

  get_source_archive "$COROSYNC_DOWNLOAD_URL" "$COROSYNC_LOCAL_ARCHIVE" "$COROSYNC_SRC_DIR"

  # Install required build tools
  apk add autoconf automake build-base libtool pkgconf
  # Install required development packages
  apk add

  # Build Corosync
  # autogen.sh not needed if installing from tarball - NOT TRUE, configure does not exist until autogen.sh is run
  ./autogen.sh
  ./configure
  make $PARALLEL_MAKE 
  make install

  # TODO: Remove Corosync, Kronosnet and LibQB source directories if no longer needed
  # TODO: Check if still needed by asterisk
  #rm -r /usr/src/corosync "$KRONOSNET_SRC_DIR" "$LIBQB_SRC_DIR"
fi

####################
# Codec2
####################

if [[ "$INSTALL_CODEC2" =~ true || "$INSTALL_ALL" =~ true ]]
  then
  # Get Codec2
  CODEC2_DOWNLOAD_URL="https://github.com/drowe67/codec2/archive/refs/tags/v$CODEC2_VERSION.tar.gz"
  CODEC2_LOCAL_ARCHIVE="$DOWNLOAD_DIR/codec2-v$CODEC2_VERSION.tar.gz"
  CODEC2_SRC_DIR='/usr/src/codec2'
  
  mkdir -p "$CODEC2_SRC_DIR"
  cd "$CODEC2_SRC_DIR" || exit

  get_source_archive "$CODEC2_DOWNLOAD_URL" "$CODEC2_LOCAL_ARCHIVE" "$CODEC2_SRC_DIR"
  
  # Install required build tools
  apk add cmake 
  # Install required development packages
  apk add 

  # Build Codec2
  # autogen.sh not needed if installing from tarball - NOT TRUE, configure does not exist until autogen.sh is run
  mkdir build_linux
  cd build_linux || exit
  # TODO: Change from make to 'cmake --build .' Change the name of the 'build_linux' to 'build' dir for consistency with other cmake runs in other deps
  cmake ..
  make $PARALLEL_MAKE
  make install

  # TODO: Remove Codec2 source directory if no longer needed
  # TODO: Check if still needed by asterisk
  #rm -r "$CODEC2_SRC_DIR"
fi

####################
# Hoard
####################

if [[ "$INSTALL_HOARD" =~ true || "$INSTALL_ALL" =~ true ]]
then
  echo "Hoard does not compile on Alpine/musl without errors."
  echo "Ignoring instruction do download and compile Hoard."
  # # Get Hoard
  # HOARD_DOWNLOAD_URL="https://github.com/emeryberger/Hoard/archive/refs/tags/$HOARD_VERSION.tar.gz"
  # HOARD_LOCAL_ARCHIVE="$DOWNLOAD_DIR/hoard-v$HOARD_VERSION.tar.gz"
  # HOARD_SRC_DIR='/usr/src/hoard'
  
  # mkdir -p "$HOARD_SRC_DIR"
  # cd "$HOARD_SRC_DIR" || exit

  # get_source_archive "$HOARD_DOWNLOAD_URL" "$HOARD_LOCAL_ARCHIVE" "$HOARD_SRC_DIR"
  
  # # Install required build tools
  # # bsd-compat-headers required to provide cdefs.h
  # apk add bsd-compat-headers clang

  # # Install required development packages
  # apk add

  # # Build Hoard
  # # autogen.sh not needed if installing from tarball - NOT TRUE, configure does not exist until autogen.sh is run
  # # ./configure
  # cd src || exit
  # make $PARALLEL_MAKE
  # make install

  # # TODO: Remove Hoard source directory if no longer needed
  # # TODO: Check if still needed by asterisk
  # #rm -r "$HOARD_SRC_DIR"
fi

####################
# Iksemel
####################

if [[ "$INSTALL_IKSEMEL" =~ true || "$INSTALL_ALL" =~ true ]]
then
  if [[ "$IKSEMEL_FORK" =~ ^debian$ ]]
  then
  # The official github repository for Iksemel is out of date and does not compile. (See https://github.com/meduketto/iksemel)
  # Debian maintain a patched version which is used here as a trusted replacement for the original.
  # Need to download Debian's copy of the orignal and their patch set.
  IKSEMEL_SRC_URL='http://deb.debian.org/debian/pool/main/libi/libiksemel/libiksemel_1.4.orig.tar.gz'
  IKSEMEL_SRC_LOCAL_ARCHIVE="$DOWNLOAD_DIR/iksemel-$IKSEMEL_FORK-original-v1.4.tar.gz"
  IKSEMEL_SRC_DIR="/usr/src/iksemel-$IKSEMEL_FORK"
  mkdir -p "$IKSEMEL_SRC_DIR"
  
  IKSEMEL_PATCH_URL="http://deb.debian.org/debian/pool/main/libi/libiksemel/libiksemel_$IKSEMEL_VERSION.debian.tar.xz"
  IKSEMEL_PATCH_LOCAL_ARCHIVE="$DOWNLOAD_DIR/iksemel-$IKSEMEL_FORK-patches-v$IKSEMEL_VERSION.tar.xz"
  IKSEMEL_PATCH_DIR="/usr/src/iksemel-$IKSEMEL_FORK-patches"
  mkdir -p "$IKSEMEL_PATCH_DIR"

  cd "$IKSEMEL_SRC_DIR" || exit
  get_source_archive "$IKSEMEL_SRC_URL" "$IKSEMEL_SRC_LOCAL_ARCHIVE" "$IKSEMEL_SRC_DIR"
  cd "$IKSEMEL_PATCH_DIR" || exit
  get_source_archive "$IKSEMEL_PATCH_URL" "$IKSEMEL_PATCH_LOCAL_ARCHIVE" "$IKSEMEL_PATCH_DIR"

  # Apply the patches
  cd "$IKSEMEL_SRC_DIR" || exit
  PATCH_LIST=$(cat $IKSEMEL_PATCH_DIR/patches/series)
  for PATCH_FILE in $PATCH_LIST
  do
    echo " "
    echo "Patching $IKSEMEL_PATCH_DIR/patches/$PATCH_FILE"
    echo " "
    # Removed --dry-run from patch command now
    patch --verbose --strip=1 --input "$IKSEMEL_PATCH_DIR/patches/$PATCH_FILE"
  done

  # Install required build tools
  # NB: TODO: Check if gnutls-dev is actually needed. ./configure complains about missing libgnutls-config script regardless...
  apk add autoconf automake gnutls-dev libtool openssl-dev python2-dev

  # NB: Unfortunately the Debian version of Iksemel is not working due to the inability
  # of the configure script to find the deprecated & long-removed gnutls script 'libgnutls-config'
  # Build Iksemel
  # autoconf
  # ./configure
  # make $PARALLEL_MAKE
  # make check
  # make install

  elif [[ "$IKSEMEL_FORK" =~ ^timothytylee$ || "$IKSEMEL_FORK" =~ ^holme-r$ ]]
  then
    IKSEMEL_LOCAL_ARCHIVE="$DOWNLOAD_DIR/iksemel-$IKSEMEL_FORK-v$IKSEMEL_VERSION.tar.gz"
    IKSEMEL_SRC_DIR="/usr/src/iksemel-$IKSEMEL_FORK"
    mkdir -p "$IKSEMEL_SRC_DIR"
    cd "$IKSEMEL_SRC_DIR" || exit
    if [[ "$IKSEMEL_FORK" =~ ^timothytylee$ ]]
    then
      IKSEMEL_DOWNLOAD_URL="https://github.com/$IKSEMEL_FORK/iksemel-1.4/archive/refs/tags/v$IKSEMEL_VERSION.tar.gz"
    elif [[ "$IKSEMEL_FORK" =~ ^holme-r$ ]]
    then
      IKSEMEL_DOWNLOAD_URL="https://github.com/$IKSEMEL_FORK/iksemel/archive/refs/tags/$IKSEMEL_VERSION.tar.gz"
    fi
    # get Iksemel
    get_source_archive "$IKSEMEL_DOWNLOAD_URL" "$IKSEMEL_LOCAL_ARCHIVE" "$IKSEMEL_SRC_DIR"
    # Install required build tools and dependencies
    apk add autoconf automake gnutls-dev libtool openssl-dev python2-dev
    ./autogen.sh
    ./configure
    make $PARALLEL_MAKE
    make check
    make install

    # Notes on timothytylee fork:
    # make gives the following errors, although 'make check' passes all 8 checks it carries out
    # make[1]: *** [Makefile:357: iksemel] Error 127
    # make[1]: Leaving directory '/usr/src/iksemel-timothytylee/doc'
    # make: *** [Makefile:438: install-recursive] Error 1
    # asterisk's own configure script is able to find the installed timothytylee fork.

  elif [[ "$IKSEMEL_FORK" =~ ^Zaryob$ ]]
  then
    IKSEMEL_SRC_DIR='/usr/src/iksemel-$IKSEMEL_FORK'
    mkdir -p "$IKSEMEL_SRC_DIR"
    cd "$IKSEMEL_SRC_DIR" || exit
    
    # The only release archive for Zaryob appears incomplete
    # IKSEMEL_LOCAL_ARCHIVE="$DOWNLOAD_DIR/iksemel-$IKSEMEL_FORK-v$IKSEMEL_VERSION.tar.gz"
    # IKSEMEL_DOWNLOAD_URL="https://github.com/$IKSEMEL_FORK/iksemel/archive/refs/tags/$IKSEMEL_VERSION.tar.gz"
    # Could download zip of master,
    # IKSEMEL_DOWNLOAD_URL="https://github.com/Zaryob/iksemel/archive/refs/heads/master.zip"
    # get_source_archive "$IKSEMEL_SRC_URL" "$IKSEMEL_LOCAL_ARCHIVE" "$IKSEMEL_SRC_DIR"
    # or... Clone the repo instead
    git clone https://github.com/Zaryob/iksemel.git "$IKSEMEL_SRC_DIR"

    # Install required build tools and dependencies
    apk add meson samurai libtool openssl-dev python3-dev

    meson build_dir
    ninja -C build
    ninja test -C build
    ninja install -C build

  else
    echo "Invalid value for IKSEMEL_FORK variable: '$IKSEMEL_FORK'"
    exit 200
  fi
  # TODO: Remove Iksemel source directory if no longer needed
  # TODO: Check if still needed by asterisk
  #rm -r "$IKSEMEL_SRC_DIR"
fi

####################
# iODBC
####################
 
if [[ "$INSTALL_IOBDC" =~ true || "$INSTALL_ALL" =~ true ]]
  then
  # Get iODBC
  IOBDC_DOWNLOAD_URL="https://github.com/openlink/iODBC/archive/refs/tags/v$IODBC_VERSION.tar.gz"
  IOBDC_LOCAL_ARCHIVE="$DOWNLOAD_DIR/iobdc-v$IOBDC_VERSION.tar.gz"
  IOBDC_SRC_DIR='/usr/src/iodbc'
  
  mkdir -p "$IOBDC_SRC_DIR"
  cd "$IOBDC_SRC_DIR" || exit

  get_source_archive "$IOBDC_DOWNLOAD_URL" "$IOBDC_LOCAL_ARCHIVE" "$IOBDC_SRC_DIR"
  
  # Install required build tools
  # ./configure complains that gtk-config is not installed (maybe alpine package kde-gtk-config). Is this really necessary?
  apk add autoconf automake libtool pkgconf
  # Install required development packages
  apk add

  # Build iODBC
  ./autogen.sh
  ./configure
  make $PARALLEL_MAKE
  make check
  make install

  # TODO: Remove iODBC source directory if no longer needed
  # TODO: Check if still needed by asterisk
  #rm -r "$IOBDC_SRC_DIR"
fi

####################
# OpenR2
####################
 
if [[ "$INSTALL_OPENR2" =~ true || "$INSTALL_ALL" =~ true ]]
  then
  # Get OpenR2
  OPENR2_DOWNLOAD_URL="https://github.com/moises-silva/openr2/archive/refs/tags/v$OPENR2_VERSION.tar.gz"
  OPENR2_LOCAL_ARCHIVE="$DOWNLOAD_DIR/openr2-v$OPENR2_VERSION.tar.gz"
  OPENR2_SRC_DIR='/usr/src/openr2'
  
  mkdir -p "$OPENR2_SRC_DIR"
  cd "$OPENR2_SRC_DIR" || exit

  get_source_archive "$OPENR2_DOWNLOAD_URL" "$OPENR2_LOCAL_ARCHIVE" "$OPENR2_SRC_DIR"
  
  # Install required build tools
  apk add libc-dev libevent-dev dahdi-tools-dev
  # Install required development packages
  apk add

  # Build OpenR2
  ./configure
  make $PARALLEL_MAKE
  make check
  make install

  # TODO: Remove OpenR2 source directory if no longer needed
  # TODO: Check if still needed by asterisk
  #rm -r "$OPENR2_SRC_DIR"
fi

####################
# SS7
####################
 
if [[ "$INSTALL_SS7" =~ true || "$INSTALL_ALL" =~ true ]]
  then
  # Get SS7
  SS7_DOWNLOAD_URL="http://downloads.asterisk.org/pub/telephony/libss7/releases/libss7-$SS7_VERSION.tar.gz"
  SS7_LOCAL_ARCHIVE="$DOWNLOAD_DIR/ss7-v$SS7_VERSION.tar.gz"
  SS7_SRC_DIR='/usr/src/ss7'
  
  mkdir -p "$SS7_SRC_DIR"
  cd "$SS7_SRC_DIR" || exit

  get_source_archive "$SS7_DOWNLOAD_URL" "$SS7_LOCAL_ARCHIVE" "$SS7_SRC_DIR"
  
  # Install required build tools
  apk add
  # Install required development packages
  apk add dahdi-linux-dev dahdi-tools-dev

  # Build SS7
  # Building on Alpine fails due to the gcc "treat all warnings as errors" flag being set
  # The only warning is (2 instance of) "warning: #warning redirecting incorrect #include <sys/poll.h> to <poll.h>"
  # Get rid of the -Werror in CFLAGS in 'Makefile'
  sed -i 's/-Werror//' Makefile
  make $PARALLEL_MAKE
  make install

  # TODO: Remove SS7 source directory if no longer needed
  # TODO: Check if still needed by asterisk
  #rm -r "$SS7_SRC_DIR"
fi

####################
# SoX
####################

if [[ "$INSTALL_SOX" =~ true || "$INSTALL_ALL" =~ true ]]
  then
  # Get TwoLame, a SoX dependency
  # NB: Sourceforge archive URL includes a ready-made configure script, doesn't need autogen.sh to be run and make also runs without errors
  TWOLAME_DOWNLOAD_URL="https://downloads.sourceforge.net/twolame/twolame-$TWOLAME_VERSION.tar.gz"
  #TWOLAME_DOWNLOAD_URL="https://github.com/njh/twolame/archive/refs/tags/$TWOLAME_VERSION.tar.gz"
  TWOLAME_LOCAL_ARCHIVE="$DOWNLOAD_DIR/twolame-v$TWOLAME_VERSION.tar.gz"
  TWOLAME_SRC_DIR='/usr/src/twolame'
  
  mkdir -p "$TWOLAME_SRC_DIR"
  cd "$TWOLAME_SRC_DIR" || exit

  get_source_archive "$TWOLAME_DOWNLOAD_URL" "$TWOLAME_LOCAL_ARCHIVE" "$TWOLAME_SRC_DIR"

  # Install required build tools
  apk add asciidoc autoconf automake doxygen libsndfile-dev libtool xmlto

  ./configure
  make $PARALLEL_MAKE
  make check
  make install

  # Get libube, a libssp dependency
  LIBUBE_DOWNLOAD_URL="https://github.com/pgarner/libube/archive/refs/tags/v$LIBUBE_VERSION.tar.gz"
  LIBUBE_LOCAL_ARCHIVE="$DOWNLOAD_DIR/libube-v$LIBUBE_VERSION.tar.gz"
  LIBUBE_SRC_DIR='/usr/src/libube'
  
  mkdir -p "$LIBUBE_SRC_DIR"
  cd "$LIBUBE_SRC_DIR" || exit

  get_source_archive "$LIBUBE_DOWNLOAD_URL" "$LIBUBE_LOCAL_ARCHIVE" "$LIBUBE_SRC_DIR"

  # Install required build tools
  apk add clang cmake curl-dev blas-dev boost-dev expat-dev gnuplot lapack-dev libsndfile-dev
  
  # build/example.sh contains a sample build script. With a little modification it is good
  # TODO: Pull request to fix missing backslash at the end of the first '-D' line
  # export CC=clang; export CXX=clang++; export USE_STATIC=0
  export CC=clang
  export CXX=clang++
  export USE_STATIC=0
  cd build || exit
  rm -rf CMakeCache.txt CMakeFiles cmake_install.cmake
  # cmake -D CMAKE_CXX_FLAGS="-Wall -Werror -std=c++14" -D CMAKE_BUILD_TYPE=minsizerel -D CMAKE_INSTALL_PREFIX=/usr ../
  cmake \
    -D CMAKE_CXX_FLAGS="-Wall -Werror -std=c++14" \
    -D CMAKE_BUILD_TYPE=minsizerel \
    -D CMAKE_INSTALL_PREFIX=/usr \
    ../
  cmake --build . $PARALLEL_CMAKE
  ctest  --verbose
  cmake --install .
  
  # Build without any parallelism
  # real	0m38.842s
  # user	0m35.625s
  # sys	0m3.211s
  # (total 77.6s)

  # Build with --parallel 4
  # real	0m16.432s
  # user	0m40.058s
  # sys	0m3.425s
  # (total 59.9s)

  # Build tests parallel vs non-parallel are consistent after 3x runs of each

  # Get libssp 
  LIBSSP_DOWNLOAD_URL="https://github.com/idiap/libssp/archive/refs/tags/v$LIBSSP_VERSION.tar.gz"
  LIBSSP_LOCAL_ARCHIVE="$DOWNLOAD_DIR/libssp-v$LIBSSP_VERSION.tar.gz"
  LIBSSP_SRC_DIR='/usr/src/libssp'
  
  mkdir -p "$LIBSSP_SRC_DIR"
  cd "$LIBSSP_SRC_DIR" || exit

  get_source_archive "$LIBSSP_DOWNLOAD_URL" "$LIBSSP_LOCAL_ARCHIVE" "$LIBSSP_SRC_DIR"

  # Install required build tools
  apk add

  cd build || exit
  rm -rf CMakeCache.txt CMakeFiles cmake_install.cmake
  cmake \
    -D CMAKE_CXX_FLAGS="-Wall -Werror -std=c++14" \
    -D CMAKE_BUILD_TYPE=minsizerel \
    -D CMAKE_BUILD_RPATH="/usr/lib/lube" \
    -D CMAKE_SKIP_BUILD_RPATH=false \
    -D CMAKE_BUILD_WITH_INSTALL_RPATH=false \
    -D CMAKE_INSTALL_RPATH="" \
    -D CMAKE_INSTALL_RPATH_USE_LINK_PATH=false \
    -D CMAKE_INSTALL_PREFIX=/usr \
    ../
  cmake --build . $PARALLEL_CMAKE

  # Thorough article on cmake and rpaths which solves the tests failing on not finding shared libraries in /usr/lib/lube
  # https://gitlab.kitware.com/cmake/community/-/wikis/doc/cmake/RPATH-handling

  # Not needed: -D CMAKE_PREFIX_PATH=/usr/lib/lube \
  # Without all the -D options above, the ctest's will fail as these files cannot be found in their /usr/lib/lube/ locations by the cmake tests that libssp has.
  # TODO: Find if this is a system-wide problem, or a hard-coded path limitation unique to the test script?
  # Fixed when placed in /lib rather than /usr/lib...
  # Trying with 'export USE_STATIC=0' set, to see if static linking the test executable was the problem...
  # No, setting 'export USE_STATIC=0' does not solve the test failure
  # Keeping CMAKE_INSTALL_PREFIX=/usr for now... that's the next thing to change
  # But there's too much installed in /usr/lib by apk add for alpine to be unaware of it!!!
  # ldconfig is limited on Alpine... there is no /etc/ld.so.conf
  # ln -s /usr/lib/lube/libsnd.so /usr/src/libssp/build/ssp/libsnd.so
  # ln -s /usr/lib/lube/libgnuplot.so /usr/src/libssp/build/ssp/libgnuplot.so
  # TODO: IMPORTANT: Find out if limiting the library paths by creating /etc/ld-musl-$(uname -m).path is going to cause problems later on...
  # echo "/lib:/usr/lib:/usr/local/lib:/usr/lib/lube" > /etc/ld-musl-$(uname -m).path
  # ldconfig -v
  # Don't like messing with the ldconfig configuration, abandoned that method of solving the problem, returning to cmake configuration

  # Tests may still fail due to very minor differences between the test's reference file '/usr/src/libssp/test/test-cochlea-ref.txt'
  # and the test output file /usr/src/libssp/build/test/test-cochlea-out.txt (and the same for the ssp test)
  # The 'failure' is a difference of the 4th or 6th significant figure of a single number in one line of results in each test...
  ctest --verbose
  TEST_STATUS=$?
  if [[ TEST_STATUS -ne 0 ]]
  then
    diff ../test/test-cochlea-ref.txt test/test-cochlea-out.txt
    diff ../test/test-ssp-ref.txt test/test-ssp-out.txt 
  fi

  cmake --install .

  # Build without any parallelism
  # real	0m8.540s
  # user	0m7.679s
  # sys	0m0.863s
  # (total 17.0s)

  # Build with --parallel 4
  # real	0m3.126s
  # user	0m8.273s
  # sys	0m0.883s
  # (total 11.4s)

  unset CC
  unset CXX
  unset USE_STATIC

  # Get SoX
  SOX_DOWNLOAD_URL="https://sourceforge.net/projects/sox/files/sox/14.4.2/sox-14.4.2.tar.gz"
  SOX_LOCAL_ARCHIVE="$DOWNLOAD_DIR/sox-v$SOX_VERSION.tar.gz"
  SOX_SRC_DIR='/usr/src/sox'
  
  mkdir -p "$SOX_SRC_DIR"
  cd "$SOX_SRC_DIR" || exit

  get_source_archive "$SOX_DOWNLOAD_URL" "$SOX_LOCAL_ARCHIVE" "$SOX_SRC_DIR"
  
  # (Optional?) Dependencies not in Alpine:
  # libube () is at https://github.com/pgarner/libube and is required to build libssp (libube requires: apk add cmake blas-dev boost-dev lapack-dev)
  # libssp (library for speech signal processing) is at https://github.com/idiap/libssp (libssp requires: apk add cmake)
  # libtwolame is at https://www.twolame.org or https://github.com/njh/twolame/
  # Install required build tools
  apk add autoconf automake
  # Install required development packages
  apk add file-dev flac-dev gsm-dev lame-dev libao-dev libid3tag-dev libmad-dev libpng-dev libsndfile-dev libvorbis-dev opencore-amr-dev opusfile-dev pulseaudio-dev sndio-dev wavpack-dev
  # TODO: maybe requires 'apk add spandsp' or 'spandsp3' for lpc10 but sox also seems to be able to obtain lpc10 'in tree' so probably not necessary?

  # Build SoX
  # Delete a line that causes compilation to fail, and live with the (minor?) consequences
  sed -i '/#error FIX NEEDED HERE/d' src/formats.c
  ./configure
  make $PARALLEL_MAKE
  make install

  # Build without any parallelism
  # real	2m22.940s
  # user	1m59.403s
  # sys	0m17.874s
  # (total 4m40.2s)

  # Build with --parallel 4
  # real	1m1.610s
  # user	2m4.801s
  # sys	  0m17.947s
  # (total 3m24.3s)

  # TODO: Remove SoX source directory if no longer needed
  # TODO: Check if still needed by asterisk
  #rm -r "$SOX_SRC_DIR"
fi

####################
# Asterisk
####################

if [[ "$INSTALL_ASTERISK" =~ true || "$INSTALL_ALL" =~ true ]]
then
  CONFIG_OUTPUT='/scripts/asterisk_configure_output.txt'
  # Get asterisk
  # Release archive here: http://downloads.asterisk.org/pub/telephony/asterisk/releases/ 

  ASTERISK_DOWNLOAD_URL="http://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-$ASTERISK_VERSION.tar.gz"
  ASTERISK_LOCAL_ARCHIVE="$DOWNLOAD_DIR/asterisk-v$ASTERISK_VERSION.tar.gz"
  ASTERISK_SRC_DIR='/usr/src/asterisk'
    
  mkdir -p "$ASTERISK_SRC_DIR"
  cd "$ASTERISK_SRC_DIR" || exit

  get_source_archive "$ASTERISK_DOWNLOAD_URL" "$ASTERISK_LOCAL_ARCHIVE" "$ASTERISK_SRC_DIR"

  # Try the contrib/scripts/install_prereq script to discover what packages are required

  # Bare minimum of packages required to get asterisk's ./configure script to successfully finish
  apk add g++ libc-dev libedit-dev musl-dev libxml2-dev sqlite-dev util-linux-dev
  # Required if using asterisk's bundled pjproject and bundled libjansson
  apk add patch
  # Required if NOT using asterisk's bundled pjproject and libjansson
  #apk add
  # Required for all other addon-modules - HEADERS
  # apk add
    
  # Required for all other addon-modules - LIBRARIES
  apk add \
    beanstalkd binutils-dev bluez-dev curl-dev dahdi-linux-dev dahdi-tools-dev ffmpeg-dev fftw-dev freeradius-client-dev freetds-dev gnu-libiconv-dev gsm-dev jack-dev libcap-dev libexecinfo-dev libical-dev\
    libpri-dev libresample libsrtp-dev libsndfile-dev lua5.4-dev libvorbis-dev libxslt-dev net-snmp-dev openldap-dev mariadb-dev neon-dev newt-dev opus-dev popt-dev portaudio-dev py3-alembic\
    opusfile-dev sdl-dev sdl_image-dev speex-dev speexdsp-dev unbound-dev unixodbc-dev uriparser-dev
    # musl-libintl alsa-lib ## 
  # NB: 'avcodec' is not found by ./configure'. It fails the single check: checking for sws_getContext in -lavcodec... no. Installing ffmpeg-dev does not help, even though /usr/include/libavcodec/avcodec.h is installed with it
  # NB: 'beanstalk is not found by ./configure' despite the Alpine package 'beanstalkd' being installed. It fails the single check: checking for bs_version in -lbeanstalk... no
  # NB: 'bfd' on Ubuntu is provided by 'libbfd-dev' and is a virtual package provided by 'binutils-dev': This is also the case on Alpine. SOLVED upon installing binutils-dev
  # NB: 'cap' needs 'libcap-dev'. SOLVED
  # NB: 'cfg' has no obvious provider on Alpine. Ubuntu reveals 'libcfg-dev' which is available from https://corosync.github.io/corosync/ - NOT resolved upon installing Corosync: missing function 'corosync_cfg_state_track' triggers error
  # NB: 'codec2' has no obvious provider on Alpine. Ubuntu reveals 'libcodec2-dev' which is available from http://rowetel.com/codec2.html - SOLVED upon installing Codec2 from source
  # NB: 'cpg' has no obvious provider on Alpine. Ubuntu reveals 'libcpg-dev' which is available from https://corosync.github.io/corosync/ - SOLVED upon installing Corosync
  # NB: 'crypto' is not found by ./configure' despite the Alpine package 'libcrypto1.1' being installed. It fails the single check: checking for AES_encrypt in -lcrypto... no. Update: SOLVED: This is now listed as installed, not sure why
  # NB: 'hoard' is not found by ./configure, apk or aptitude search facilities... Found a well-known project called "hoard memory allocator" on github, installed, still fails the check "checking for malloc in -lhoard... no"
  # NB: 'iksemel' is not availabe in the alpine repositories. It is available from https://github.com/meduketto/iksemel
  # NB: 'iodbc' is not available in the alpine repositories, It is available in Ubuntu as either 'libiodbc2-dev' or as a freeradius addon module 'freeradius-iodbc'
  # NB: Only keep the latest version of lua to install, removed: lua5.1-dev lua5.2-dev lua5.3-dev
  # NB: 'sybdb' is not satisfied by anthing in the Alpine repositories. It is related to the 'freetds' package (same homepage) but probably needs the non-existant -dev version of the package
  # NB: 'openr2' is not available on Alpine. It is available from https://www.libopenr2.org
  # NB: 'ss7' is not available on Alpine. It is available from Asterisk themselves: http://downloads.asterisk.org/pub/telephony/libss7/
  # NB: ''
  # library functions
  # NB: Resolve whether sdl2 or sdl required: It is sdl, not sdl2
  # sdl
  # sdl-dev <-- needed for 'sdl-config'
  # sdl_image
  # sdl_image-dev <-- needed for 'SDL_image.h'


  # Required for all other addon-modules - EXECUTABLES
  apk add bison curl graphviz doxygen flex libxml2-utils python2 python3 xmlstarlet

  # file linux-headers curl-dev neon sox
  # # Build dependencies, essential, core, codecs
  # # https://wiki.asterisk.org/wiki/display/AST/System+Libraries
  # apk add \
  #   libxml2-dev libxslt-dev ncurses-dev openssl-dev \
  #   dahdi-linux-dev unixodbc-dev speex-dev speexdsp-dev libresample libcurl libvorbis-dev libogg-dev libical-dev neon-dev gmime-dev unbound-dev \
  #   libedit-dev \
  #   opus-dev lame-dev \
  #   libmariadb-dev-compat libsnmp-dev

  # # Runtime dependencies, essential, core, codecs
  # apk add \
  #   sqlite libxml2 libxslt ncurses openssl util-linux python3 \
  #   dahdi-linux unixodbc-dev speex speexdsp libvorbis libogg libical neon gmime unbound-libs \
  #   # libedit
  #   opus lame \
  # bison flex doxygen dot curl xmlstarlet xml alembic soxmix md5 curl-config libcurl (installed but not usable?) uriparser xlocale.h 
  # winsock.h(windows only??) libexplain-dev(for vfork.h) "UW IMAP Toolkit c-client library" "system c-client library" "SQLConnect in iodbc" 
  # jack(lib/dev) mysql_config net-snmp-config newt bluetooth beanstalk pg_config portaudio pri?? fftw3 sndfile SpanDSP ss7 openr2 lua freeradius-client radcli codec2 \
  # cpg cfg srtp hoard sybdb tonezone linux/compiler.h sys/socket.h sdl-config SDL_image avcodec linux/videodev.h launchd GTK2!! Systemd!! tinfo(lib)
  # DON'T KNOW IF NEEDED libxml2-utils  libintl graphviz unbound (seems unbound-dev is sufficient)???

  # NB: CANNOT FIND libiksemel, sox, alembic  
  # NB: pjproject (bundled) includes a version of libsrtp... does asterisk still complain about srtp in config output?
  # https://wiki.asterisk.org/wiki/display/AST/Installing+libsrtp

  # Relevant configure script options
  # --prefix=PREFIX             (install architecture-independent files in PREFIX [/usr/local])
  # --exec-prefix=EPREFIX       (install architecture-dependent files in EPREFIX [PREFIX])
  # --enable-permanent-dlopen   (Enable when your libc has a permanent dlopen like musl)
  # --with-gnu-ld               (assume the C compiler uses GNU ld [default=no])
  # --with-download-cache=PATH  (use cached sound AND external module tarfiles in PATH)
  # --with-sounds-cache=PATH    (use cached sound tarfiles in PATH)
  # --with-jansson-bundled      (Use bundled jansson library)
  # --with-pjproject-bundled    (Use bundled pjproject libraries (default: yes))
  # --with-pjproject=PATH (use PJPROJECT files in PATH)

  # cd /usr/src/asterisk/ && /usr/src/asterisk/configure --enable-permanent-dlopen --with-gnu-ld --with-jansson-bundled=yes --with-pjproject-bundled=yes | tee /scripts/asterisk_configure_output.txt
  ./configure \
    --enable-permanent-dlopen \
    --with-gnu-ld \
    --with-jansson-bundled=yes \
    --with-pjproject-bundled=yes | tee "$CONFIG_OUTPUT"

  # make $PARALLEL_MAKE
fi
############################################################
# Install, build and configure FreePBX and its dependencies
############################################################

#wget -P /tmp
