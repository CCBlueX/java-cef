This page lists notes for JCEF releases.

**Contents**

- [Background](#background)
- [Development](#development)
- [Building from Source Code](#building-from-source-code)
  - [Building with Docker or GitHub Actions](#building-with-docker-or-github-actions)
  - [Building Manually](#building-manually)
    - [Downloading Source Code](#downloading-source-code)
    - [Building](#building)
    - [Packaging](#packaging)

---

# Background

The JCEF project is an extension of the Chromium Embedded Framework project hosted at <https://github.com/chromiumembedded/cef>. JCEF maintains a development branch that tracks the most recent CEF release branch. JCEF source code (both native code and Java code) can be built manually as described below.

# Development

Ongoing development of JCEF occurs on the [master branch](https://github.com/chromiumembedded/java-cef/tree/master). This location tracks the current CEF3 release branch.

# Building from Source Code

Building JCEF from source code is currently supported on Windows, Linux and MacOS for 64-bit Oracle Java targets. 32-bit builds are also possible on Windows and Linux but they are untested.

To build JCEF from source code you should begin by installing the build prerequisites for your operating system and development environment. For all platforms this includes:

* [CMake](http://cmake.org/download/) version 3.21 or newer.
* [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git).
* [Java](https://java.com/en/download/) version 7 to 14.
* [Python](https://www.python.org/downloads/) version 2.6+ or 3+.

For Linux platforms:

* Currently supported distributions include Debian 10 (Buster), Ubuntu 18 (Bionic Beaver), and related. Ubuntu 18.04 64-bit with GCC 7.5.0+ is recommended. Newer versions will likely also work but may not have been tested. Required packages include: build-essential, libgtk-3-dev.

For MacOS platforms:

* [Apache Ant](https://ant.apache.org/bindownload.cgi) is required to build the Java app bundle.
* Java version newer than 8u121 is required.
* Xcode 13.5 to 16.4 building on MacOS 12.0 (Monterey) or newer. The Xcode command-line tools must also be installed.

For Windows platforms:

* Visual Studio 2022 building on Windows 10 or newer. Windows 10/11 64-bit is recommended.

## Building with Docker or GitHub Actions

For a quick and easy build setup, you can run your builds on Docker (Linux/Windows) or use GitHub Actions (with Docker). The [jcefbuild repository on GitHub](https://github.com/jcefmaven/jcefbuild) can be forked and used to compile your own custom sources, providing one-line build scripts for each platform, Docker environments for Linux and Windows, as well as GitHub Actions workflows for all platforms. It also adds support for more build
architectures (arm64 + arm/v6 on Linux, arm64 on Windows). For more information, visit the repository readme file.

## Building Manually

Building can also be performed as a series of manual steps.

### Downloading Source Code

Download JCEF source code using Git.

```sh
# The JCEF source code will exist at `/path/to/java-cef/src`
cd /path/to/java-cef
git clone https://github.com/chromiumembedded/java-cef.git src
```

### Building

1\. Run CMake to generate platform-specific project files and then build the resulting native targets. See CMake output for any additional steps that may be necessary. For example, to generate a Release build of the `jcef` and `jcef_helper` targets:

```sh
# Enter the JCEF source code directory.
cd /path/to/java-cef/src

# Create and enter the `jcef_build` directory.
# The `jcef_build` directory name is required by other JCEF tooling
# and should not be changed.
mkdir jcef_build && cd jcef_build

# Linux: Generate 64-bit Unix Makefiles.
cmake -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release ..
# Build using Make.
make -j4

# MacOS: Generate 64-bit Xcode project files.
cmake -G "Xcode" -DPROJECT_ARCH="x86_64" ..
# Open jcef.xcodeproj in Xcode
# - Select Scheme > Edit Scheme and change the "Build Configuration" to "Release"
# - Select Product > Build.

# MacOS: Generate ARM64 Xcode project files.
cmake -G "Xcode" -DPROJECT_ARCH="arm64" ..
# Open jcef.xcodeproj in Xcode
# - Select Scheme > Edit Scheme and change the "Build Configuration" to "Release"
# - Select Product > Build.

# Windows: Generate 64-bit VS2022 project files.
cmake -G "Visual Studio 17" -A x64 ..
# Open jcef.sln in Visual Studio
# - Select Build > Configuration Manager and change the "Active solution configuration" to "Release"
# - Select Build > Build Solution.
```

JCEF supports a number of different project formats via CMake including [Ninja](http://martine.github.io/ninja/). See comments in the top-level [CMakeLists.txt](https://github.com/chromiumembedded/java-cef/blob/master/CMakeLists.txt) file for additional CMake usage instructions.

2\. On Windows and Linux build the JCEF Java classes using the _compile.[bat\|sh]_ tool.

```sh
cd /path/to/java-cef/src/tools
compile.bat win64
```

On MacOS the JCEF Java classes are already built by the CMake project.

3\. On Windows and Linux test that the resulting build works using the _run.[bat\|sh]_ tool. You can either run the simple example (see java/simple/MainFrame.java) or the detailed one (see java/detailed/MainFrame.java) by appending "detailed" or "simple" to the _run.[bat\|sh]_ tool. This example assumes that the "Release" configuration was built in step 1 and that you want to use the detailed example.

```sh
cd /path/to/java-cef/src/tools
run.bat win64 Release detailed
```

On MacOS run jcef\_app for the detailed example. Either use the command-line or double-click on jcef\_app in Finder.

```sh
cd /path/to/java-cef/src/jcef_build/native/Release
open jcef_app.app
```

### Packaging

After building the Release configurations you can use the _make\_distrib.[bat\|sh]_ script to create a binary distribution.

```sh
cd /path/to/java-cef/src/tools
make_distrib.bat win64
```

If the process succeeds a binary distribution package will be created in the /path/to/java-cef/src/binary\_distrib directory. See the README.txt file in that directory for usage instructions.