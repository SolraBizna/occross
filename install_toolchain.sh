#!/bin/sh

set -e

# We can easily write the script to handle spaces, but I wouldn't count on
# EVERYTHING crosstool-ng uses to handle spaces correctly.

# This script's policy is to test for spaces, and otherwise omit double-quotes
# to aid readability.

if ! which grep >/dev/null; then
    echo "Uhhh... you don't have grep. Interesting. Fix that."
    exit 1
fi

if echo "$0" | grep -q " "; then
    echo "Please move this directory to a path that does not contain spaces."
    exit 1
fi

if echo "$OCCROSS_INSTALL_DIR" | grep -q " "; then
    echo "Please do not try to install to a path that contains spaces."
    exit 1
fi

cd $(dirname $0)
OCCROSS_BUILD_DIR="$(pwd)"

if echo "$OCCROSS_BUILD_DIR" | grep -q " "; then
    echo "Please move this directory to a path that does not contain spaces."
fi

# These, if present, will royally screw up the build. Hopefully your compiler
# doesn't need any of them to create runnable code...
unset CFLAGS CXXFLAGS LDFLAGS CPPFLAGS ASFLAGS

# Try to make sure there aren't any tools missing. Don't try very hard.

which cc > /dev/null \
    || (echo "Couldn't find a C compiler. Install one and try again."; exit 1)

if [ `uname` = "Darwin" ]; then
    which help2man > /dev/null \
    || (echo "help2man is required for crosstool-ng. You can install it with \
Homebrew via:"; echo "brew install help2man"; exit 1)
    which gsed > /dev/null \
    || (echo "GNU sed is required for crosstool-ng. You can install it with \
Homebrew via:"; echo "brew install gnu-sed"; exit 1)
    which gobjcopy > /dev/null \
    || (echo "GNU binutils is required for crosstool-ng. You can install it \
with Homebrew via:"; echo "brew install binutils"; exit 1)
    which gawk > /dev/null \
    || (echo "GNU awk is required for crosstool-ng. You can install it with \
Homebrew via:"; echo "brew install gawk"; exit 1)
    which wget > /dev/null \
    || (echo "GNU wget is required for crosstool-ng. You can install it with \
Homebrew via:"; echo "brew install wget"; exit 1)
fi

for tool in git make c++ gperf help2man flex bison wget autoconf makeinfo \
                libtool; do
    which $tool > /dev/null \
    || (echo "Couldn't find $tool. Install it and/or add it to your PATH and \
try again."; exit 1)
done

for gnutool in make awk sed; do
    if which g$gnutool > /dev/null; then
        true # we definitely have the GNU version
    elif $gnutool -v 2>&1 | grep -q GNU; then
        true # we even more definitely have the GNU version
    else
        cat <<EOF
It doesn't look like you have the GNU version of $gnutool installed.
crosstool-ng is cranky. It requires the GNU versions of make, awk, and sed.
EOF
        exit 1
    fi
done

# Get the build and install directories.

if [ -z "$OCCROSS_INSTALL_DIR" ]; then
    OCCROSS_INSTALL_DIR=/opt/occross
fi

mkdir -p $OCCROSS_INSTALL_DIR

if ! touch $OCCROSS_INSTALL_DIR/.writable; then
    echo "$OCCROSS_INSTALL_DIR needs to be writable by your user."
fi

rm -f ?ase_sensitivity_test
touch case_sensitivity_test Case_sensitivity_test
if [ ! `ls ?ase_sensitivity_test | wc -l` -eq 2 ]; then
    rm -f ?ase_sensitivity_test
    cat <<EOF
You are using a case-insensitive filesystem. crosstool-ng requires a case-
sensitive one.
EOF
    if [ `uname` = "Darwin" ]; then
    cat <<EOF
The easiest way to fix this is to create a case sensitive disk image using Disk
Utility and copy this directory to that disk.
Make sure it's at least 6GB in size.
EOF
    else
    cat <<EOF
If you are on Cygwin, you will need to change the registry value:
HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel\obcaseinsensitive
to 0 and reboot your machine.
EOF
    fi
    exit 1
fi
rm -f ?ase_sensitivity_test

# Get and build crosstool-ng
export PATH="$OCCROSS_BUILD_DIR/bin:$PATH"
if [ ! -x $OCCROSS_BUILD_DIR/bin/ct-ng ]; then
    echo "Setting up crosstool-ng, this should only take a minute..."
    if [ ! -d crosstool-ng ]; then
        git clone https://github.com/crosstool-ng/crosstool-ng.git
    fi
    cd crosstool-ng
    git checkout f7f70b67c44727d9eea48997c837e87c5e63ca33
    if [ `uname` = "Darwin" ]; then
        patch -p1 <<EOF
diff --git a/scripts/build/debug/300-gdb.sh b/scripts/build/debug/300-gdb.sh
index ee4753e..86c26e5 100644
--- a/scripts/build/debug/300-gdb.sh
+++ b/scripts/build/debug/300-gdb.sh
@@ -92,7 +92,7 @@ do_debug_gdb_build() {
             cross_extra_config+=("--disable-nls")
         fi
 
-        CC_for_gdb="\${CT_HOST}-gcc \${CT_CFLAGS_FOR_HOST} \${CT_LDFLAGS_FOR_HOST}"
+        CC_for_gdb="\${CT_HOST}-gcc \${CT_CFLAGS_FOR_HOST} \${CT_LDFLAGS_FOR_HOST} -Qunused-arguments"
         LD_for_gdb="\${CT_HOST}-ld \${CT_LDFLAGS_FOR_HOST}"
         if [ "\${CT_GDB_CROSS_STATIC}" = "y" ]; then
             CC_for_gdb+=" -static"
EOF
    fi
    ./bootstrap
    ./configure --prefix=$OCCROSS_BUILD_DIR
    make
    make install
    cd ..
fi

if echo "$1" | grep -q "[^-_a-z]"; then
    echo "That's obviously not a valid target name."
    echo "Run \"install_toolchain.sh --targets\" to see the list of targets."
    exit 1
elif [ "$1" = "targets" -o ! -f config/$1.cfg ]; then
    cat <<EOF

Known targets:
armeb-oc_arm-eabi
  OC-ARM architecture, in Big-Endian mode.
arm-oc_arm-eabi
  OC-ARM architecture, in the non-recommended Little-Endian mode.
arm-openarms-eabi
  OpenARMs architecture. (always Little-Endian)

EOF
    exit 0
elif [ -z "$1" ]; then
    cat <<EOF

Usage: install-toolchain.sh <target>

Example: install-toolchain.sh armeb-oc_arm-eabi
     OR: install-toolchain.sh targets
         (to see the list of targets)

IMPORTANT NOTE: Building and installing a cross-toolchain takes a LOT of disk
space (>5GB) and a LOT of time (>1 hour). Be prepared!

Once the compilation is complete, the build files will be deleted, and the
toolchain will likely be around 200 megabytes.

EOF
    if [ -z "$1" ]; then
        exit 0
    else
        exit 1
    fi
fi

TARGET_ARCH=$1

if [ -d $OCCROSS_INSTALL_DIR/$TARGET_ARCH ]; then
    cat <<EOF

WARNING!

You appear to already have the $TARGET_ARCH toolchain installed!

If you continue, that toolchain will be deleted and replaced with a newly-built
one. If this is what you want, type YES (in all caps) and hit return.
EOF
    read IN
    if [ "$IN" != "YES" ]; then
        echo "You typed something other than YES. Aborting."
        exit 0
    else
        echo "Okay, proceeding with the build..."
    fi
fi

rm -rf build/build-$TARGET_ARCH
mkdir -p build/build-$TARGET_ARCH

cd build/build-$TARGET_ARCH
# fun fact: space is the only character we know is NOT in $OCCROSS_INSTALL_DIR
sed -e "s __OCCROSS_INSTALL_DIR__ $OCCROSS_INSTALL_DIR " \
    < ../../config/$TARGET_ARCH.cfg > .config
ct-ng oldconfig </dev/null
ct-ng build
cd ../..
rm -rf build/build-$TARGET_ARCH

cat <<EOF

Your cross-toolchain has been built and installed in:

$OCCROSS_INSTALL_DIR/$TARGET_ARCH

The build files have been deleted to save space. Congratulations, and enjoy
your new toolchain!

EOF
