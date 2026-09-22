This page provides information about building OpenJDK locally for use in debugging JCEF.

**Contents**

- [Overview](#overview)
- [OpenJDK on Windows](#openjdk-on-windows)
  - [Install prerequisite software](#install-prerequisite-software)
  - [Build Freetype2](#build-freetype2)
  - [Setup MinGW](#setup-mingw)
  - [Download OpenJDK sources](#download-openjdk-sources)
  - [Patch OpenJDK sources](#patch-openjdk-sources)
  - [Configure OpenJDK](#configure-openjdk)
  - [Build OpenJDK](#build-openjdk)
  - [Run JCEF with OpenJDK](#run-jcef-with-openjdk)
- [OpenJDK on Linux](#openjdk-on-linux)
  - [Mixed mode debugging with GDB](#mixed-mode-debugging-with-gdb)

---

# Overview

[OpenJDK](http://openjdk.java.net/) is the open source project on which the Oracle JDK is based. Oracle does not provide debugging symbols for the JDK. Consequently it is necessary to build OpenJDK locally in order to debug issues that trace into JDK code. General instructions for building OpenJDK are available [here](http://hg.openjdk.java.net/build-infra/jdk8/raw-file/tip/README-builds.html), however it is recommended that you follow the below steps when building on Windows.

# OpenJDK on Windows

Building OpenJDK on Windows is a many-step process. Below are instructions for creating a 32-bit or 64-bit build of OpenJDK at version 8u60 on Windows 7 or newer using Visual Studio 2013.

## Install prerequisite software

OpenJDK requires the following software. Install all software at the default location.

* Visual Studio 2013 Update 4 Professional. Other versions may work but are untested.
* [Java 8 Development Kit](http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html). Choose the architecture version that matches the desired OpenJDK build (e.g. choose the x64 version if creating a 64-bit OpenJDK build).
* [Mercurial](https://www.mercurial-scm.org/wiki/Download).

## Build Freetype2

OpenJDK requires Freetype2 which should be built locally for best results [[*]](http://stackoverflow.com/questions/6207176/compiling-freetype-to-dll-as-opposed-to-static-library) [[*]](https://technfun.wordpress.com/2015/08/03/building-openjdk-8-for-windows-using-msys/).

1\. Download Freetype2 source code in the 2.x series. For example, [freetype-2.6.2.tar.gz](http://sourceforge.net/projects/freetype/files/freetype2/2.6.2/).

2\. Extract the archive contents to "C:\code\freetype-2.6.2-src"

3\. Open Visual Studio 2013 and load the "C:\code\freetype-2.6.2-src\builds\windows\vc2010\freetype.sln" solution file.

4\. Select Build > Configuration Manager from the top menu:

* Change configuration to "Release".
* Change platform to either "Win32" or "x64" to match the desired OpenJDK build.

5\. Right click on the "freetype" solution, select Properties, and in the General tab:

* Change Configuration Type to "Dynamic Library (.dll)".
* Change Target Name to "freetype" (remove the version number).

6\. Open the ftoption.h file and add the following lines near the "DLL export compilation" remarks section:

```
#define FT_EXPORT(x) __declspec(dllexport) x
#define FT_BASE(x) __declspec(dllexport) x
```

7\. Build the project. You should now have "C:\code\freetype-2.6.2-src\objs\vc2010\[Win32\|x64]\freetype.[dll\|lib]" files.

8\. Create a new "C:\code\freetype-2.6.2-src\lib" directory and copy the freetype.[dll\|lib] files into it.

## Setup MinGW

OpenJDK can be built using MinGW or Cygwin on Windows. This is how to setup the MinGW build environment.

1\. Install MinGW using [mingw-get-setup.exe](http://sourceforge.net/projects/mingw/files/Installer/). Install to the default location (C:\MinGW).

2\. Use the "C:\MinGW\bin\mingw-get.exe install <package>" command to install the following packages:

* msys-autoconf
* msys-base
* msys-bsdcpio
* msys-make
* msys-mktemp
* msys-unzip
* msys-zip

3\. Create a "C:\MinGW\msys\1.0\etc\fstab" file with the following contents:

```
#Win32_Path		Mount_Point
c:/mingw		/mingw
c:/		      /c
```

4\. Create a "C:\MinGW\msys\1.0\home\\[User]\\.profile" file ([User] is your Windows user name) with the following contents:

```sh
export PATH="$PATH:/C/Program Files/Mercurial"
```

5\. Run "C:\MinGW\msys\1.0\msys.bat" to enter the MinGW shell.

## Download OpenJDK sources

Run the following commands in the MinGW shell to download the OpenJDK source code for version 8u60.

```sh
cd /c/code
hg clone http://hg.openjdk.java.net/jdk8u/jdk8u60/ openjdk8
cd openjdk8
bash ./get_source.sh
```

## Patch OpenJDK sources

JDK version 8 does not officially support building with VS2013. However, the build should succeed if you apply the below patches. These patches resolve the following issues:

* The cpio utility does not exist in MinGW. Change "cpio" to "bsdcpio" in basics.m4 [[*]](https://bugs.openjdk.java.net/browse/JDK-8022177).
* MinGW installs autoconf 2.68. Change the version requirement in configure.ac [[*]](https://technfun.wordpress.com/2015/08/03/building-openjdk-8-for-windows-using-msys/).
* Configure cannot find msvcr100.dll with correct architecture. Fix the logic in toolchain_windows.m4 [[*]](http://cr.openjdk.java.net/~simonis/webrevs/8022177/).
* ad_x86_64_misc.obj : error LNK2011: precompiled object not linked in. Fix compile.make and vm.make to link against _build_pch_file.obj [[*]](https://bugs.openjdk.java.net/browse/JDK-8043492).
* LNK2038: mismatch detected for 'RuntimeLibrary'. Remove _STATIC_CPPLIB defines in toolchain.m4 [[*]](http://hg.openjdk.java.net/jdk9/client/rev/39ee0ee4f890).
* The make command hangs during the build process. Disable multiple jobs in spec.gmk.in [[*]](https://bugs.openjdk.java.net/browse/JDK-8022177).
* The value "IMVERSION" of attribute "version" in element "assemblyIdentity" is invalid (SxS manifest issue). Add a version number to java.manifest [[*]](https://bugs.openjdk.java.net/browse/JDK-8128079).

```
--- common/autoconf/basics.m4  Thu Jan 28 18:46:45 2016
+++ common/autoconf/basics.m4  Thu Jan 28 16:44:34 2016
@@ -279,7 +279,7 @@
   BASIC_REQUIRE_PROG(CMP, cmp)
   BASIC_REQUIRE_PROG(COMM, comm)
   BASIC_REQUIRE_PROG(CP, cp)
-  BASIC_REQUIRE_PROG(CPIO, cpio)
+  BASIC_REQUIRE_PROG(CPIO, bsdcpio)
   BASIC_REQUIRE_PROG(CUT, cut)
   BASIC_REQUIRE_PROG(DATE, date)
   BASIC_REQUIRE_PROG(DIFF, [gdiff diff])

--- common/autoconf/configure.ac   Thu Jan 28 18:46:37 2016
+++ common/autoconf/configure.ac   Thu Jan 28 16:44:53 2016
@@ -30,7 +30,7 @@
 ###############################################################################


-AC_PREREQ([2.69])
+AC_PREREQ([2.68])
 AC_INIT(OpenJDK, jdk8, build-dev@openjdk.java.net,,http://openjdk.java.net)

 AC_CONFIG_AUX_DIR([build-aux])

--- common/autoconf/toolchain_windows.m4   Thu Jan 28 18:46:29 2016
+++ common/autoconf/toolchain_windows.m4   Thu Jan 28 16:46:42 2016
@@ -240,12 +240,22 @@
     # Need to check if the found msvcr is correct architecture
     AC_MSG_CHECKING([found msvcr100.dll architecture])
     MSVCR_DLL_FILETYPE=`$FILE -b "$POSSIBLE_MSVCR_DLL"`
+    if test "x$OPENJDK_BUILD_OS_ENV" = "xwindows.msys"; then
+      # The MSYS 'file' command returns "PE32 executable for MS Windows (DLL) (GUI) Intel 80386 32-bit"
+      # on x32 and "PE32+ executable for MS Windows (DLL) (GUI) Mono/.Net assembly" on x64 systems.
+      if test "x$OPENJDK_TARGET_CPU_BITS" = x32; then
+        CORRECT_MSVCR_ARCH="PE32 executable"
+      else
+        CORRECT_MSVCR_ARCH="PE32+ executable"
+      fi
+    else
     if test "x$OPENJDK_TARGET_CPU_BITS" = x32; then
       CORRECT_MSVCR_ARCH=386
     else
       CORRECT_MSVCR_ARCH=x86-64
     fi
-    if $ECHO "$MSVCR_DLL_FILETYPE" | $GREP $CORRECT_MSVCR_ARCH 2>&1 > /dev/null; then
+    fi
+    if $ECHO "$MSVCR_DLL_FILETYPE" | $GREP "$CORRECT_MSVCR_ARCH" 2>&1 > /dev/null; then
       AC_MSG_RESULT([ok])
       MSVCR_DLL="$POSSIBLE_MSVCR_DLL"
       AC_MSG_CHECKING([for msvcr100.dll])

--- hotspot/make/windows/makefiles/vm.make Thu Jan 28 18:46:14 2016
+++ hotspot/make/windows/makefiles/vm.make     Thu Jan 28 17:00:04 2016
@@ -128,8 +128,8 @@

 !if "$(USE_PRECOMPILED_HEADER)" != "0"
 CXX_USE_PCH=/Fp"vm.pch" /Yu"precompiled.hpp"
-!if "$(COMPILER_NAME)" == "VS2012"
-# VS2012 requires this object file to be listed:
+!if "$(COMPILER_NAME)" == "VS2012" || "$(COMPILER_NAME)" == "VS2013"
+# VS2012 and VS2013 require this object file to be listed:
 LD_FLAGS=$(LD_FLAGS) _build_pch_file.obj
 !endif
 !else

--- hotspot/make/windows/makefiles/compile.make    Thu Jan 28 18:46:06 2016
+++ hotspot/make/windows/makefiles/compile.make    Thu Jan 28 17:07:44 2016
@@ -147,6 +147,9 @@
 !if "$(MSC_VER)" == "1700"
 COMPILER_NAME=VS2012
 !endif
+!if "$(MSC_VER)" == "1800"
+COMPILER_NAME=VS2013
+!endif
 !endif

 # By default, we do not want to use the debug version of the msvcrt.dll file

--- common/autoconf/toolchain.m4   Thu Jan 28 18:45:57 2016
+++ common/autoconf/toolchain.m4   Thu Jan 28 17:54:04 2016
@@ -998,7 +998,7 @@
       ;;
     cl )
       CCXXFLAGS_JDK="$CCXXFLAGS $CCXXFLAGS_JDK -Zi -MD -Zc:wchar_t- -W3 -wd4800 \
-      -D_STATIC_CPPLIB -D_DISABLE_DEPRECATE_STATIC_CPPLIB -DWIN32_LEAN_AND_MEAN \
+      -DWIN32_LEAN_AND_MEAN \
       -D_CRT_SECURE_NO_DEPRECATE -D_CRT_NONSTDC_NO_DEPRECATE \
       -DWIN32 -DIAL"
       case $OPENJDK_TARGET_CPU in

--- common/autoconf/spec.gmk.in    Thu Jan 28 18:45:47 2016
+++ common/autoconf/spec.gmk.in    Thu Jan 28 17:57:06 2016
@@ -267,7 +267,7 @@
 SJAVAC_SERVER_DIR:=@SJAVAC_SERVER_DIR@

 # Number of parallel jobs to use for compilation
-JOBS?=@JOBS@
+JOBS?=1

 FREETYPE_LIBS:=@FREETYPE_LIBS@
 FREETYPE_CFLAGS:=@FREETYPE_CFLAGS@

--- jdk/src/windows/resource/java.manifest  Thu Jan 28 18:45:19 2016
+++ jdk/src/windows/resource/java.manifest  Thu Jan 28 18:36:40 2016
@@ -4,7 +4,7 @@
           xmlns:asmv3="urn:schemas-microsoft-com:asm.v3"
 >
 <assemblyIdentity
-    version="IMVERSION"
+    version="8.0.60.0"
     processorArchitecture="X86"
     name="Oracle Corporation, Java(tm) 2 Standard Edition"
     type="win32"

```

## Configure OpenJDK

Run the following commands in the MinGW shell to configure OpenJDK. If you installed all of the required packages and applied the above patches correctly the configure command should succeed. If you experience errors then debug the problem before proceeding further.

To disable all optimizations in the debug build use `--with-debug-level=slowdebug` instead of `--enable-debug` on the configure line. The resulting folder will then be `windows-*-normal-server-slowdebug` instead of `windows-*-normal-server-fastdebug`.

```sh
cd /c/code/openjdk8

# OpenJDK expects the "VS100COMNTOOLS" variable which is set by the VS2010 install.
# Set it to use the VS2013 install instead.
export VS100COMNTOOLS=$VS120COMNTOOLS

# Don't compress symbol files into .diz ("debug info zip") files.
export ZIP_DEBUGINFO_FILES=0

# 32-bit build.
# Explicitly specify the 32-bit boot JDK path and increase the Java memory limit.
bash ./configure --enable-debug --with-target-bits=32 –-with-freetype=/c/code/freetype-2.6.2-src -with-boot-jdk=/c/Program\ Files\ \(x86\)/Java/jdk1.8.0_66/ --with-boot-jdk-jvmargs="-Xmx6G -enableassertions"

# 64-bit build.
bash ./configure --enable-debug --with-target-bits=64 –-with-freetype=/c/code/freetype-2.6.2-src
```

## Build OpenJDK

Run the following commands in the MinGW shell to build OpenJDK. VS2013 doesn't create .manifest files so adding MT= disables running of the mt.exe tool. The build should take approximately 20 minutes on a fast machine. The resulting JDK will be output to "C:\code\openjdk8\build\windows-x86_64-normal-server-fastdebug\images\j2sdk-image" (or the 32-bit path as appropriate).

```sh
cd /c/code/openjdk8

make all MT=
```

## Run JCEF with OpenJDK

To use the resulting JDK build with JCEF follow these steps.

1\. Create a Debug build of JCEF as described on the [Branches And Building](branches_and_building.md) page.

2\. Download Debug Symbols for the CEF version from <https://cef-builds.spotifycdn.com/index.html> and extract libcef.dll.pdb to "src\jcef_build\native\Debug".

3\. Edit JCEF's "src\tools\run.bat" script. Replace the "java" command with "C:\code\openjdk8\build\windows-x86_64-normal-server-fastdebug\jdk\bin\java" (or the 32-bit path as appropriate).

4\. Run the script:

```
run.bat win64 Debug detailed
```

5\. Open Visual Studio 2013 and load the "src\jcef_build\jcef.sln" solution file.

6\. Select Debug > Attach to process.. from the top menu and choose the "java.exe" process.

7\. Wait for the application to crash. Get a call stack with debug symbols like [this](https://github.com/chromiumembedded/java-cef/issues/157).

8\. To delay Java startup long enough to attach the debugger add the following code at the top of the `main(String [] args)` method in "src\java\tests\detailed\MainFrame.java":

```
try { Thread.sleep(10000); /* delay 10 seconds */ } catch(InterruptedException e) {}
```

# OpenJDK on Linux

Issues on Linux can be diagnosed using a local debug build of OpenJDK based on [these instructions](http://cr.openjdk.java.net/~ihse/demo-new-build-readme/common/doc/building.html#getting-the-source-code). You will need to build JDK8 on an Ubuntu 14.04 machine because a 3.x series kernel is required by the build configuration.

```sh
# Install dependencies
> sudo apt-get update --fix-missing
> sudo apt-get install build-essential mercurial openjdk-7-jdk libx11-dev libxext-dev libxrender-dev libxtst-dev libxt-dev libelf-dev libffi-dev libcups2-dev
# Download source code
> hg clone http://hg.openjdk.java.net/jdk8/jdk8
> cd jdk8
> bash get_source.sh
# Configure
> bash configure --enable-debug --disable-zip-debug-info --disable-ccache
# Build
> make images
# Test that it runs
> ./build/linux-x86_64-normal-server-fastdebug/jdk/bin/java -version
```

For GDB to successfully load OpenJDK debug symbols you need to run using the binaries in the ./build/linux-x86_64-normal-server-fastdebug/jdk/bin directory (where the *.debuginfo files exist). For example, by setting the following environment variables:

```sh
export JAVA_HOME=/home/marshall/code/openjdk/jdk8/build/linux-x86_64-normal-server-fastdebug/jdk  
export PATH=/home/marshall/code/openjdk/jdk8/build/linux-x86_64-normal-server-fastdebug/jdk/bin:$PATH
```

## Mixed mode debugging with GDB

[This link](http://progdoc.de/papers/Joker2014/joker2014.html#(5)) describes how to get mixed native and Java stack traces using GDB. It's also useful to add System.out.println messages to code under the jdk/src directory and re-build.

Here's a patch that launches the JCEF sample apps using GDB and Java debug settings:

```
diff --git tools/run.sh tools/run.sh
index 1a58940..466afdb 100755
--- tools/run.sh
+++ tools/run.sh
@@ -32,7 +32,7 @@ else
     shift
     shift
 
-    LD_PRELOAD=$LIB_PATH/libcef.so java -cp "$CLS_PATH" -Djava.library.path=$LIB_PATH tests.$RUN_TYPE.MainFrame "$@"
+    LD_PRELOAD=$LIB_PATH/libcef.so gdb --args java -Dsun.awt.disablegrab=true -Xdebug -Xint -cp "$CLS_PATH" -Djava.library.path=$LIB_PATH tests.$RUN_TYPE.MainFrame "$@"
   fi
 fi
 
```

Here's a patch that adds a CefApp.debugBreak() method that can be used to trigger a native breakpoint from Java code:

```cpp
diff --git java/org/cef/CefApp.java java/org/cef/CefApp.java
index 4545c68..a7135f2 100644
--- java/org/cef/CefApp.java
+++ java/org/cef/CefApp.java
@@ -543,6 +543,14 @@ public class CefApp extends CefAppHandlerAdapter {
         return library_path;
     }
 
+    /**
+     * Trigger a breakpoint in the native debugger.
+     */
+    public static final void debugBreak() {
+        N_DebugBreak();
+    }
+
+    private final static native void N_DebugBreak();
     private final static native boolean N_Startup();
     private final native boolean N_PreInitialize();
     private final native boolean N_Initialize(
diff --git native/CefApp.cpp native/CefApp.cpp
index 39a14d8..0f61a1c 100644
--- native/CefApp.cpp
+++ native/CefApp.cpp
@@ -6,6 +6,7 @@
 
 #include <string>
 
+#include "include/base/cef_logging.h"
 #include "include/cef_app.h"
 #include "include/cef_version.h"
 
@@ -104,3 +105,8 @@ JNIEXPORT jboolean JNICALL Java_org_cef_CefApp_N_1Startup(JNIEnv*, jclass) {
 #endif  // defined(OS_MACOSX)
   return JNI_TRUE;
 }
+
+JNIEXPORT void JNICALL Java_org_cef_CefApp_N_1DebugBreak(JNIEnv*, jclass) {
+  DCHECK(false) << "CefApp.DebugBreak";
+}
+
diff --git native/CefApp.h native/CefApp.h
index bf1c1ef..081ffd8 100644
--- native/CefApp.h
+++ native/CefApp.h
@@ -74,6 +74,13 @@ Java_org_cef_CefApp_N_1ClearSchemeHandlerFactories(JNIEnv*, jobject);
  */
 JNIEXPORT jboolean JNICALL Java_org_cef_CefApp_N_1Startup(JNIEnv*, jclass);
 
+/*
+ * Class:     org_cef_CefApp
+ * Method:    N_DebugBreak
+ * Signature: ()V
+ */
+JNIEXPORT void JNICALL Java_org_cef_CefApp_N_1DebugBreak(JNIEnv*, jclass);
+
 #ifdef __cplusplus
 }
 #endif
```

Example GDB usage in combination with the above patches:

```sh
$ ./run.sh linux64 Debug detailed
(gdb) r

0x00007ffff2736a07 in operator() () at ../../base/logging.cc:874
874	../../base/logging.cc: No such file or directory.
(gdb) bt
#0  0x00007ffff2736a07 in operator() () at ../../base/logging.cc:874
#1  ~LogMessage () at ../../base/logging.cc:874
#2  0x00007ffff2627b6b in cef_log () at ../../cef/libcef/common/base_impl.cc:333
#3  0x00007fffc4d151e5 in cef::logging::LogMessage::~LogMessage (this=0x7fffc41b2470, __in_chrg=<optimized out>)
    at /home/marshall/code/java-cef/src/third_party/cef/cef_binary_3.3626.1883.g00e6af4_linux64/libcef_dll/base/cef_logging.cc:187
#4  0x00007fffc4cc62bd in Java_org_cef_CefApp_N_1DebugBreak () at /home/marshall/code/java-cef/src/native/CefApp.cpp:110
#5  0x00007fffcd0262e7 in ?? ()
#6  0x00007fffdc38d000 in ?? ()
#7  0x00007fffc41b2618 in ?? ()
#8  0x00007fffe0a1c298 in ?? ()
#9  0x00007fffc41b2670 in ?? ()
#10 0x00007fffe0a1e230 in ?? ()
#11 0x0000000000000000 in ?? ()

(gdb) call help()

"Executing help"
basic
  pp(void* p)   - try to make sense of p
  pv(intptr_t p)- ((PrintableResourceObj*) p)->print()
  ps()          - print current thread stack
  pss()         - print all thread stacks
  pm(int pc)    - print Method* given compiled PC
  findm(intptr_t pc) - finds Method*
  find(intptr_t x)   - finds & prints nmethod/stub/bytecode/oop based on pointer into it
misc.
  flush()       - flushes the log file
  events()      - dump events from ring buffers
compiler debugging
  debug()       - to set things up for compiler debugging
  ndebug()      - undo debug

(gdb) call ps()

"Executing ps"
 for thread: "AWT-EventQueue-0" #9 prio=6 os_prio=0 tid=0x00007fffdc38d000 nid=0xb818 runnable [0x00007fffc41b2000]
   java.lang.Thread.State: RUNNABLE
   JavaThread state: _thread_in_native
Thread: 0x00007fffdc38d000  [0xb818] State: _running _has_called_back 0 _at_poll_safepoint 0
   JavaThread state: _thread_in_native

 1 - frame( sp=0x00007fffc41b2610, unextended_sp=0x00007fffc41b2610, fp=0x00007fffc41b2658, pc=0x00007fffcd026233)
org.cef.CefApp.N_DebugBreak(Native Method)
 2 - frame( sp=0x00007fffc41b2668, unextended_sp=0x00007fffc41b2678, fp=0x00007fffc41b26b8, pc=0x00007fffcd007500)
[Thread 0x7fff527fc700 (LWP 47146) exited]
org.cef.CefApp.debugBreak(CefApp.java:550)
 3 - frame( sp=0x00007fffc41b26c8, unextended_sp=0x00007fffc41b26c8, fp=0x00007fffc41b2708, pc=0x00007fffcd007500)
tests.simple.MainFrame$6.windowDeactivated(MainFrame.java:188)
 4 - frame( sp=0x00007fffc41b2718, unextended_sp=0x00007fffc41b2718, fp=0x00007fffc41b2768, pc=0x00007fffcd007545)
java.awt.AWTEventMulticaster.windowDeactivated(AWTEventMulticaster.java:399)
 5 - frame( sp=0x00007fffc41b2778, unextended_sp=0x00007fffc41b2778, fp=0x00007fffc41b27c8, pc=0x00007fffcd007545)
java.awt.AWTEventMulticaster.windowDeactivated(AWTEventMulticaster.java:399)
 6 - frame( sp=0x00007fffc41b27d8, unextended_sp=0x00007fffc41b27d8, fp=0x00007fffc41b2828, pc=0x00007fffcd007545)
java.awt.Window.processWindowEvent(Window.java:2073)
 7 - frame( sp=0x00007fffc41b2838, unextended_sp=0x00007fffc41b2840, fp=0x00007fffc41b2890, pc=0x00007fffcd007500)
javax.swing.JFrame.processWindowEvent(JFrame.java:297)
 8 - frame( sp=0x00007fffc41b28a0, unextended_sp=0x00007fffc41b28a0, fp=0x00007fffc41b28f0, pc=0x00007fffcd007500)
java.awt.Window.processEvent(Window.java:2017)
 9 - frame( sp=0x00007fffc41b2900, unextended_sp=0x00007fffc41b2900, fp=0x00007fffc41b2950, pc=0x00007fffcd007500)
java.awt.Component.dispatchEventImpl(Component.java:4883)
10 - frame( sp=0x00007fffc41b2960, unextended_sp=0x00007fffc41b2990, fp=0x00007fffc41b29e0, pc=0x00007fffcd007500)
java.awt.Container.dispatchEventImpl(Container.java:2292)
11 - frame( sp=0x00007fffc41b29f0, unextended_sp=0x00007fffc41b2a00, fp=0x00007fffc41b2a50, pc=0x00007fffcd007500)
java.awt.Window.dispatchEventImpl(Window.java:2739)
12 - frame( sp=0x00007fffc41b2a60, unextended_sp=0x00007fffc41b2a60, fp=0x00007fffc41b2ab0, pc=0x00007fffcd007500)
java.awt.Component.dispatchEvent(Component.java:4705)
13 - frame( sp=0x00007fffc41b2ac0, unextended_sp=0x00007fffc41b2ac0, fp=0x00007fffc41b2b10, pc=0x00007fffcd007500)
java.awt.KeyboardFocusManager.redispatchEvent(KeyboardFocusManager.java:1954)
14 - frame( sp=0x00007fffc41b2b20, unextended_sp=0x00007fffc41b2b20, fp=0x00007fffc41b2b78, pc=0x00007fffcd007500)
java.awt.DefaultKeyboardFocusManager.typeAheadAssertions(DefaultKeyboardFocusManager.java:995)
15 - frame( sp=0x00007fffc41b2b88, unextended_sp=0x00007fffc41b2bb0, fp=0x00007fffc41b2c08, pc=0x00007fffcd006e80)
java.awt.DefaultKeyboardFocusManager.dispatchEvent(DefaultKeyboardFocusManager.java:685)
16 - frame( sp=0x00007fffc41b2c18, unextended_sp=0x00007fffc41b2c60, fp=0x00007fffc41b2cb0, pc=0x00007fffcd006e80)
java.awt.Component.dispatchEventImpl(Component.java:4754)
17 - frame( sp=0x00007fffc41b2cc0, unextended_sp=0x00007fffc41b2cf0, fp=0x00007fffc41b2d40, pc=0x00007fffcd007500)
java.awt.Container.dispatchEventImpl(Container.java:2292)
18 - frame( sp=0x00007fffc41b2d50, unextended_sp=0x00007fffc41b2d60, fp=0x00007fffc41b2db0, pc=0x00007fffcd007500)
java.awt.Window.dispatchEventImpl(Window.java:2739)
19 - frame( sp=0x00007fffc41b2dc0, unextended_sp=0x00007fffc41b2dc0, fp=0x00007fffc41b2e10, pc=0x00007fffcd007500)
java.awt.Component.dispatchEvent(Component.java:4705)
20 - frame( sp=0x00007fffc41b2e20, unextended_sp=0x00007fffc41b2e20, fp=0x00007fffc41b2e70, pc=0x00007fffcd007500)
java.awt.EventQueue.dispatchEventImpl(EventQueue.java:746)
21 - frame( sp=0x00007fffc41b2e80, unextended_sp=0x00007fffc41b2e80, fp=0x00007fffc41b2ed8, pc=0x00007fffcd007500)
java.awt.EventQueue.access$400(EventQueue.java:97)
22 - frame( sp=0x00007fffc41b2ee8, unextended_sp=0x00007fffc41b2ee8, fp=0x00007fffc41b2f40, pc=0x00007fffcd007500)
java.awt.EventQueue$3.run(EventQueue.java:697)
23 - frame( sp=0x00007fffc41b2f50, unextended_sp=0x00007fffc41b2f50, fp=0x00007fffc41b2f98, pc=0x00007fffcd007430)
java.awt.EventQueue$3.run(EventQueue.java:691)
C frame (sp=0x00007fffc41b2fa8 unextended sp=0x00007fffc41b2fa8, fp=0x00007fffc41b3010, real_fp=0x00007fffc41b3010, pc=0x00007fffcd000671)
(~Stub::call_stub)
     BufferBlob (0x00007fffcd0003d0) used for StubRoutines (1)
```