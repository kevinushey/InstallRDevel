CLANG="/Users/kevin/.llvm/build/Release/bin/clang"

CC="${CLANG} -std=gnu99 -fsanitize=address,undefined -fno-omit-frame-pointer"
CFLAGS="-g -O2 -Wall -pedantic -mtune=native"
CXX="${CLANG}++ -fsanitize=address,undefined -fno-omit-frame-pointer"
CXXFLAGS="-g -O2 -Wall -pedantic -mtune=native"
F77="gfortran -fsanitize=address"
FC="gfortran -fsanitize=address"

CC=${CC} CFLAGS=${CFLAGS} CXX=${CXX} CXXFLAGS=${CXXFLAGS} F77=${F77} FC=${FC} ./install-homebrew.sh
