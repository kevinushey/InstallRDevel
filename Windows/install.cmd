REM This script installs R-devel from SVN trunk on Windows.
REM
REM This script assumes you have 'wget' on your path, as it
REM is used to download. You can find a binary here:
REM
REM     https://eternallybored.org/misc/wget/wget64.exe 
REM
REM We use SVN to checkout R trunk from SVN.
REM If you need a Windows SVN client, you can download SlikSVN here:
REM
REM     https://sliksvn.com/download/
REM
REM Be sure to place the installed binary directory on your PATH.
REM
REM If you modify the configuration below, be sure to use
REM a directory _within the %USERPROFILE%; ie, your user
REM directory; otherwise you will almost certainly run into
REM very bizarre permission issues on build.
REM
REM TODO: Get this to generate an installer that provides
REM both 32bit and 64bit R.

REM ---------------------------------
REM - BEGIN CONFIGURATION VARIABLES -
REM ---------------------------------

REM Set to 32 for a 32bit build.
REM TODO Build both in one go.
SET "WIN=64"

IF NOT DEFINED WGET (
	where /q wget && (
		SET "WGET=wget"
	) || (
		where /q wget && (
			SET "WGET=wget64"
		)
	)
)

IF NOT DEFINED SVN (
	SET "SVN=svn"
)

IF NOT DEFINED ROOT_DIR (
	SET "ROOT_DIR=%USERPROFILE%\R-src"
)

if NOT DEFINED RTOOLS_DIR (
	SET "RTOOLS_DIR=C:\Rtools"
)

IF NOT DEFINED RTOOLS_BIN_DIR (
	SET "RTOOLS_BIN_DIR=C:\Rtools\bin"
)

IF NOT DEFINED TMPDIR (
	SET "TMPDIR=%USERPROFILE%\tmp"
)

REM Set some variables both for cleanup + download of
REM required tools.
SET "OLDDIR=%CD%"
SET "CRAN=http://cran.r-project.org"
SET "RTOOLS_VERSION=33"
SET "R_HOME=%ROOT_DIR%\trunk"

REM -------------------------------
REM - END CONFIGURATION VARIABLES -
REM -------------------------------

REM Ensure that some essential tools are on the PATH.
where /Q %WGET% || (
	ECHO wget not found on PATH; exiting
	exit /b
)

where /Q %SVN% || (
	ECHO svn not found on PATH; exiting
	exit /b
)

REM Set the current directory.
if not exist "%ROOT_DIR%" (
	mkdir "%ROOT_DIR%"
)
cd "%ROOT_DIR%"
SET "OLDPATH=%PATH%"

REM URI to RTools.exe
SET "RTOOLS_URL=%CRAN%/bin/windows/Rtools/Rtools%RTOOLS_VERSION%.exe"
wget -c %RTOOLS_URL%

REM Install Rtools.
SET "RTOOLS_INSTALLER=.\Rtools%RTOOLS_VERSION%.exe"
"%RTOOLS_INSTALLER%" /VERYSILENT

REM Put Rtools on the path.
SET "PATH=%RTOOLS_BIN_DIR%;%PATH%"

REM After installing Rtools, we evidently need to rename
REM binary files so that they're picked up on installation.
REM Fortunately, we have Rtools now so we can use that
REM rather than vanilla CMD stuff to do the file munging
REM here...  Still, I am not sure why this step is needed
REM (it seems more likely that I am missing some step
REM upstream)
cd %RTOOLS_DIR%\gcc492_64\bin
find * -not -name "x86*" -exec cp {} "x86_64-w64-mingw32-{}" ;
cd %RTOOLS_DIR%\gcc492_32\bin
find * -not -name "i686*" -exec cp {} "i686-w64-mingw32-{}" ;
cd %ROOT_DIR%

REM Download the R sources. Get the latest R-devel sources using SVN.
svn checkout https://svn.r-project.org/R/trunk/
cd trunk

REM Copy in the 'extras' for a 64bit build. This includes
REM tcltk plus some other libraries. Note that the R64
REM directory should have been populated by the RTools
REM installation.
rmdir /S /Q %R_HOME%\Tcl
xcopy /E /Y C:\R64 %R_HOME%\

REM Ensure the temporary directory exists.
if not exist "%TMPDIR%" (
	mkdir "%TMPDIR%"
)

REM Create the binary directories that will eventually be
REM populated ourselves, rather than letting the bundled
REM cygwin toolkit do it. The RTools 'mkdir' apparently can
REM build directories without read permissions, which will
REM cause any attempt to link to DLLs within those folders
REM to fail.
rmdir /S /Q bin
mkdir bin\i386
mkdir bin\x64

REM Move into the root directory for 'Windows' builds.
cd src\gnuwin32

REM Since we're building from source, we need to get
REM Recommended packages.
make rsync-recommended

REM Download external software -- libpng, libgsl, and so on.
REM NOTE: It appears that the Makefile rule used here might
REM infer the current R version as 3.3; the files, however,
REM exist in a 3.2 directory, so we manually modify that
REM ourselves here. (We just modify the VERSION file, which
REM the Makefile rule uses to scrape that.)
echo 3.2.0 Under development (unstable)> ..\..\VERSION
make rsync-extsoft

REM Look at MkRules.dist and if settings need to be altered,
REM copy it to MkRules.local and edit the settings there.
if exist MkRules.local (
	rm MkRules.local
)

REM This seems unneeded.
REM cp MkRules.dist MkRules.local

REM Ensure that the make rules are properly set -- need to
REM point to 'extsoft'. NOTE: We have to be careful to write
REM these files out without any trailing whitespace!
echo LOCAL_SOFT = $(R_HOME)/extsoft>> MkRules.local
echo EXT_LIBS = $(LOCAL_SOFT)>> MkRules.local
echo MIKTEX =>> MkRules.local

REM Attempt to fix up permissions before the build.
cacls %R_HOME% /T /E /G BUILTIN\Users:R > NUL
cacls %TMPDIR% /T /E /G BUILTIN\Users:R > NUL

REM Make it!  For this part, we ensure only Rtools is on the
REM PATH. This is important as if the wrong command line
REM utilites are picked up things can fail for strange
REM reason. In particular, we _must_ use the Rtools 'sort',
REM _not_ the Windows 'sort', or else we will get strange
REM errors from 'comm' when attempting to compare sorted
REM files. Probably just placing Rtools first on the PATH is
REM sufficient, but this is fine too.
SET "PATH=C:\Rtools\bin;C:\Rtools\gcc492_64\bin"
make distclean

REM Now we should be able to build R + recommended packages.
make WIN=%WIN% all recommended

REM Clean up.
SET "PATH=%OLDPATH%"
cd %OLDDIR%
