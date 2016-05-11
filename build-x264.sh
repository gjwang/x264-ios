#!/bin/sh

# Get location of the script itself .. thanks SO ! http://stackoverflow.com/a/246128
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SOURCE="$(readlink "$SOURCE")"
[[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
PROJECT_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"


CONFIGURE_FLAGS="--enable-static --enable-pic --disable-cli"

ARCHS="arm64 x86_64 i386 armv7 armv7s"

# directories
SOURCE="x264"
FAT="x264-iOS"

SCRATCH="scratch-x264"
# must be an absolute path
THIN=`pwd`/"thin-x264"

# the one included in x264 does not work; specify full path to working one
#gas-preprocessor.pl: https://github.com/libav/gas-preprocessor.git
#or gas-preprocessor.pl in x264 source: x264/tools/gas-preprocessor.pl
#At least in x264 git_version=3b70645597 works
GAS_PREPROCESSOR="$PROJECT_DIR/gas-preprocessor/gas-preprocessor.pl"
#GAS_PREPROCESSOR="$PROJECT_DIR/$SOURCE/tools/gas-preprocessor.pl"



COMPILE="y"
LIPO="y"

if [ "$*" ]
then
	if [ "$*" = "lipo" ]
	then
		# skip compile
		COMPILE=
	else
		ARCHS="$*"
		if [ $# -eq 1 ]
		then
			# skip lipo
			LIPO=
		fi
	fi
fi

if [ "$COMPILE" ]
then
	CWD=`pwd`
	for ARCH in $ARCHS
	do
		echo "building $ARCH..."
		mkdir -p "$SCRATCH/$ARCH"
		cd "$SCRATCH/$ARCH"
		CFLAGS="-arch $ARCH"
                ASFLAGS=

		if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
		then
		    PLATFORM="iPhoneSimulator"
		    CPU=
		    if [ "$ARCH" = "x86_64" ]
		    then
		    	CFLAGS="$CFLAGS -mios-simulator-version-min=7.0"
		    	HOST=
		    else
		    	CFLAGS="$CFLAGS -mios-simulator-version-min=5.0"
			HOST="--host=i386-apple-darwin"
		    fi
		else
		    PLATFORM="iPhoneOS"
		    if [ $ARCH = "arm64" ]
		    then
		        HOST="--host=aarch64-apple-darwin"
			XARCH="-arch aarch64"
		    else
		        HOST="--host=arm-apple-darwin"
			XARCH="-arch arm"
		    fi
                    CFLAGS="$CFLAGS -fembed-bitcode -mios-version-min=7.0"
                    ASFLAGS="$CFLAGS"
		fi

		XCRUN_SDK=`echo $PLATFORM | tr '[:upper:]' '[:lower:]'`
		CC="xcrun -sdk $XCRUN_SDK clang"
		if [ $PLATFORM = "iPhoneOS" ]
		then
		    export AS="$GAS_PREPROCESSOR $XARCH -- $CC"
		else
		    export -n AS
		fi
		CXXFLAGS="$CFLAGS"
		LDFLAGS="$CFLAGS"

		CC=$CC $CWD/$SOURCE/configure \
		    $CONFIGURE_FLAGS \
		    $HOST \
		    --extra-cflags="$CFLAGS" \
		    --extra-asflags="$ASFLAGS" \
		    --extra-ldflags="$LDFLAGS" \
		    --prefix="$THIN/$ARCH" || exit 1

		mkdir extras
		ln -s $GAS_PREPROCESSOR extras

		make -j3 install || exit 1
		cd $CWD
	done
fi

if [ "$LIPO" ]
then
	echo "building fat binaries..."
	mkdir -p $FAT/lib
	set - $ARCHS
	CWD=`pwd`
	cd $THIN/$1/lib
	for LIB in *.a
	do
		cd $CWD
		lipo -create `find $THIN -name $LIB` -output $FAT/lib/$LIB
	done

	cd $CWD
	cp -rf $THIN/$1/include $FAT
fi
