#!/usr/bin/env sh

## This script installs the latest R devel, using clang, the latest
## version of gfortran, and also OpenBLAS for faster matrix operations.
##
## Note: this script will install Homebrew, a Mac package manager,
## for easy downloading of gfortran, OpenBLAS, LAPACK.
##
## NOTE: If you get weird linker errors related to `lapack` in grDevices
## on load, it's probably because you updated gcc / gfortran and now
## the lapack / openblas links are broken. You can either fix this
## manually with otool, or be lazy and just reinstall openblas and
## lapack (in that order).
##

## ----- CONFIGURATION VARIABLES ----- ##

# Installation-related
INSTALLDIR=${INSTALLDIR:=/Library/Frameworks} # NOTE: needs 'sudo' on make install
SOURCEDIR=${SOURCEDIR:=~/R-devel}             # checked out R sources will live here
TMP=${TMP:=${HOME}/tmp}                       # temporary dir used on installation

## Compiler-specific
CC=${CC:=clang}
CXX=${CXX:=clang++}
CFLAGS=${CFLAGS:=-g -O3 -Wall -pedantic}
CXXFLAGS=${CXXFLAGS:=-g -O3 -Wall -pedantic}
FORTRAN=${FORTRAN:=gfortran}
FFLAGS=${FFLAGS:=-g -O3 -Wall -pedantic}
OBJC=${OBJC:=clang}
OBJCFLAGS=${OBJCFLAGS:=${CFLAGS}}
MAKE=${MAKE:=make}
MAKEFLAGS=${MAKEFLAGS:=-j10}

## ----- END CONFIGURATION VARIABLES ----- ##

OWD="$(pwd)"

## check if homebrew is installed
echo "Checking for Homebrew..."
if command -v brew > /dev/null 2>&1 ; then
    echo "> Homebrew already installed."
else
    echo "> Installing homebrew..."
    ruby -e "$(curl -fsSL https://raw.github.com/mxcl/homebrew/go/install)"
fi

export TMP=${TMP}
mkdir ${TMP} 2> /dev/null

missing () {
    if ! test -z `brew ls | grep ^$1$`; then
        echo 1
    fi
}

install () {
    if test -z `missing $1`; then
        brew install $1
        brew link --force $1
    fi
}

## make sure we have the necessary taps
brew tap homebrew/science 2> /dev/null
brew tap homebrew/dupes   2> /dev/null

## use homebrew to install openblas, lapack, gfortran

install gcc                        # gfortran
install openblas                   # faster BLAS
install lapack                     # latest lapack
install texinfo                    # vignettes, help
install coreutils                  # greadlink
install jpeg                       # image write support
install cairo                      # image write support

## Make sure the gfortran libraries get symlinked.
if command -v gfortran &> /dev/null; then
	GFORTRAN=gfortran
elif command -v gfortran-4.9 &> /dev/null; then
	GFORTRAN=gfortran-4.9
fi

## Do some path munging and symlink fortran libraries
## to /usr/local/lib
GFORTRAN_BINPATH=`which ${GFORTRAN} | xargs greadlink -f | xargs dirname`
GFORTRAN_LIBPATH=${GFORTRAN_BINPATH}/../lib/gcc/4.9/
GFORTRAN_LIBPATH=`greadlink -f ${GFORTRAN_LIBPATH}`

for file in ${GFORTRAN_LIBPATH}/libgfortran*; do
    echo Symlinking file: ${file##*/}
    rm /usr/local/lib/${file##*/} 2> /dev/null
    ln -fs "${file}" /usr/local/lib/${file##*/}
done;

## Download R-devel from SVN
cd ~
mkdir -p ${SOURCEDIR} &> /dev/null
cd ${SOURCEDIR}
echo "Checking out latest R..."
svn checkout https://svn.r-project.org/R/trunk/
cd trunk

## After downloading the R sources you should also download
## the recommended packages by entering the R source tree and running
echo "Syncing recommended R packages..."
./tools/rsync-recommended

## This was needed for building some applications that included
## 'Rinterface.h' in multiple translation units (we were encountering
## linker errors)
echo Adding a missing extern in 'Rinterface.h'...
sed -i '' 's/^int R_running_as_main_program/extern int R_running_as_main_program/g' include/Rinterface.h
sed -i '' 's/^int R_running_as_main_program/extern int R_running_as_main_program/g' src/include/Rinterface.h

## For some reason, there is trouble in locating Homebrew Cairo;
## we have to make sure pkg-config looks in the right place
export PKG_CONFIG_PATH=/opt/X11/lib/pkgconfig

## modify config.site so that it gets the appropriate compilers etc
rm config.site
touch config.site
echo CC=\"${CC}\" >> config.site
echo CFLAGS=\"${CFLAGS}\" >> config.site
echo CXX=\"${CXX}\" >> config.site
echo CXXFLAGS=\"${CXXFLAGS}\" >> config.site
echo F77=\"${FORTRAN}\" >> config.site
echo FFLAGS=\"${FFLAGS}\" >> config.site
echo FC=\"${FORTRAN}\" >> config.site
echo FCFLAGS=\"${FFLAGS}\" >> config.site
echo OBJC=\"${OBJC}\" >> config.site
echo OBJCFLAGS=\"${OBJCFLAGS}\" >> config.site
echo MAKE=\"${MAKE}\" >> config.site
echo MAKEFLAGS=\"${MAKEFLAGS}\" >> config.site

make distclean
make clean

## configure
./configure \
    --with-blas="-L/usr/local/opt/openblas/lib -lopenblas" \
    --with-lapack="-L/usr/local/opt/lapack/lib -llapack" \
    --with-cairo \
    --enable-R-framework \
    --enable-R-shlib \
    --with-readline \
    --enable-R-profiling \
    --enable-memory-profiling \
    --with-valgrind-instrumentation=2 \
    --without-internal-tzcode \
    --prefix=${INSTALLDIR} \
    $@

make -j10

echo "Installing to system library: please enter your password so we can 'sudo make install'\n"

if test "${INSTALLDIR}" = "/Library/Frameworks"; then
	sudo make install
else
	make install
fi

echo Installation completed successfully\!
cd ${OWD}

