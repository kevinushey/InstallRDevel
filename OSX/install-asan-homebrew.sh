# Try to use the development version of clang if available
if [ -f "/usr/local/llvm/bin/clang" ]; then
    CLANG=/usr/local/llvm/bin/clang
else
    CLANG=clang
fi

# Set up compiler variables
CC="${CLANG} -std=gnu99 -fsanitize=address,undefined -fno-omit-frame-pointer"
CFLAGS="-g -O2 -Wall -pedantic -mtune=native"
CXX="${CLANG}++ -fsanitize=address,undefined -fno-omit-frame-pointer"
CXXFLAGS="-g -O2 -Wall -pedantic -mtune=native"
F77="gfortran -fsanitize=address"
FC="gfortran -fsanitize=address"

# Invoke install homebrew script with these variables
CC=${CC} CFLAGS=${CFLAGS} CXX=${CXX} CXXFLAGS=${CXXFLAGS} F77=${F77} FC=${FC} ./install-homebrew.sh
