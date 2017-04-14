#!/bin/bash

BASE=$(readlink -f $0)
BASE=$(dirname $BASE) # up one
BASE=$(dirname $BASE) # up one more
BASE=$BASE/ardour

ARDOUR_SRC_DIR=${ARDOUR_SRC_DIR:=$BASE}

cd $ARDOUR_SRC_DIR || exit 1

ARDOUR_BRANCH=`git rev-parse --abbrev-ref HEAD`

cd - || exit 1

EXTERNAL_LIBS="--use-external-libs"
TESTS="--test --single-tests"
TEST_BACKENDS="--with-backends=jack,dummy,alsa"
GTK_DISABLE_DEPRECATED="--gtk-disable-deprecated"
RELEASE_BACKENDS="--with-backends=jack,dummy,alsa"
GTK3="--use-gtk3"
OPTIMIZE="--optimize"
CLASS_TRACKING="--class-tracking"
# debug-symols and profile are only relevent for optimized builds as default
# builds include debug symbols and the default optimization flag(at least for
# gcc is -O0 that doesn't omit the frame pointer
DEBUG="--debug-symbols --backtrace"
PROFILE="--profile"
GPROFILE="--gprofile"
# Puts all symbols(including static) in the dynamic symbol table so generating
# stack traces at run-time will give a symbol name for static application/GUI
# symbols rather than an address/offset
BACKTRACE="--backtrace"

declare -A config
config["debug"]="$DEBUG $TEST_BACKENDS"
config["debug-gtk3"]="$DEBUG $TEST_BACKENDS $GTK_DISABLE_DEPRECATED $GTK3"
config["debug-nojack"]="$DEBUG --with-backend=dummy,alsa"
config["debug-gtk-deprecated"]="$DEBUG $TEST_BACKENDS $GTK_DISABLE_DEPRECATED"
config["debug-tests"]="$DEBUG $TESTS $TEST_BACKENDS"
config["debug-tests-internal-libs"]="$DEBUG $TESTS $TEST_BACKENDS --noconfirm"
config["debug-tests-internal-libs-gprofile"]="$DEBUG $TESTS $TEST_BACKENDS $GPROFILE --noconfirm"
config["debug-tests-single"]="$DEBUG $TESTS $TEST_BACKENDS"
config["debug-tests-class-tracking"]="$DEBUG $TESTS $TEST_BACKENDS $BACKTRACE $CLASS_TRACKING"
config["debug-tests-cxx11"]="$DEBUG $TESTS $TEST_BACKENDS --cxx11"
config["debug-tests-amalgamated"]="$DEBUG $TESTS $TEST_BACKENDS --enable-amalgamation"
config["release"]="$RELEASE_BACKENDS $OPTIMIZE"
config["optimize-debug"]="$RELEASE_BACKENDS $OPTIMIZE $DEBUG"
config["optimize-debug-no-threaded-waveviews"]="$RELEASE_BACKENDS $OPTIMIZE $DEBUG --no-threaded-waveviews"
config["optimize-debug-tests"]="$TESTS $RELEASE_BACKENDS $OPTIMIZE $DEBUG"
config["optimize-debug-profile"]="$RELEASE_BACKENDS $OPTIMIZE $DEBUG $PROFILE"
config["optimize-debug-gprofile"]="$RELEASE_BACKENDS $OPTIMIZE $DEBUG $GPROFILE"

function print_usage ()
{
	echo "usage: ardour-build [-l] [-h] <command> <config>"
	echo " "
	echo "The commands are:"
	echo "    configure"
	echo "    build"
	echo "    install"
	echo "    clean"
}

function print_configs ()
{
	echo "Possible build configurations: "
	echo "${!config[@]}"
}

OPTIND=1
while getopts "h?vl" opt; do
	case "$opt" in
		h)
			print_usage
			exit 0
			;;
		v)
			ARDOUR_BUILD_VERBOSE=1
			set -x
			;;
		l)
			print_configs
			exit 0
			;;
	esac
done
shift "$((OPTIND-1))"

if [ -z "$1" ] || [ -z "$2" ]; then
	print_usage
	echo "You must specify command and build config"
	exit 1
fi

ARDOUR_BUILD_COMMAND="$1"
ARDOUR_BUILD_CONFIG="$2"
ARDOUR_BUILD_SCRIPT_PATH=$( cd $(dirname $0) ; pwd -P )
ARDOUR_BUILD_ROOT="$ARDOUR_BUILD_SCRIPT_PATH/BUILD"
ARDOUR_INSTALL_ROOT="$ARDOUR_BUILD_SCRIPT_PATH/INSTALL"

ARDOUR_SRC_PATH=$( cd $ARDOUR_SRC_DIR ; pwd -P )

if [ "$ARDOUR_SRC_PATH" = "$ARDOUR_BUILD_SCRIPT_PATH" ]; then
	echo "You can not use this script from within the Ardour source directory"
	echo "as you want the BUILD output directory be in another location so"
	echo "rsync will not go into an indefinite loop!"
	exit 1
fi

CONFIG_BUILD_DIR="$ARDOUR_BUILD_ROOT/$ARDOUR_BRANCH-$ARDOUR_BUILD_CONFIG"
CONFIG_WAF_BUILD_DIR="$CONFIG_BUILD_DIR/build"
CONFIG_INSTALL_DIR="$ARDOUR_INSTALL_ROOT/$ARDOUR_BRANCH-$ARDOUR_BUILD_CONFIG"

mkdir -p $ARDOUR_BUILD_ROOT || exit 1
mkdir -p $ARDOUR_INSTALL_ROOT || exit 1

function sync ()
{
	rsync -av --delete --exclude /build --exclude /.lock* --exclude /.waf* $ARDOUR_SRC_DIR/ $CONFIG_BUILD_DIR || exit 1
}

function configure ()
{
	sync
	cd $CONFIG_BUILD_DIR || exit 1
	./waf configure ${config["$ARDOUR_BUILD_CONFIG"]} "$@"
}

function build ()
{
	sync
	cd $CONFIG_BUILD_DIR || exit 1
	./waf "$@"
}

function install ()
{
	sync
	cd $CONFIG_BUILD_DIR || exit 1
	./waf install --destdir="$CONFIG_INSTALL_DIR" "$@"
}

function clean ()
{
	cd $CONFIG_BUILD_DIR || exit 1
	rm -rf $CONFIG_WAF_BUILD_DIR
}

if [ "${config["$ARDOUR_BUILD_CONFIG"]+isset}" ]; then
	echo "Using configuration: $ARDOUR_BUILD_CONFIG"
else
	echo "No such configuration: $ARDOUR_BUILD_CONFIG"
	print_configs
	exit 1
fi;

# remove the command and config parameters
shift 2

case $ARDOUR_BUILD_COMMAND in
	configure)
		configure $@ || exit 1
		;;
	build)
		build $@ || exit 1
		;;
	install)
		install $@ || exit 1
		;;
	clean)
		clean || exit 1
		;;
	*)
		print_usage
		exit 1
		;;
esac
