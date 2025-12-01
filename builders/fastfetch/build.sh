#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Config
# -----------------------------
PACKAGE_NAME="fastfetch"
PACKAGE_VERSION="2.55.1"
DEB_DIR="/tmp/${PACKAGE_NAME}-ios"
BUILD_DIR="${DEB_DIR}/build"
INSTALL_DIR="${DEB_DIR}/package"
SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
ARCH="arm64"

# -----------------------------
# Clean previous builds
# -----------------------------
rm -rf "$DEB_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$INSTALL_DIR"

# -----------------------------
# Clone Fastfetch
# -----------------------------
git clone https://github.com/fastfetch-cli/fastfetch.git "$BUILD_DIR"

# -----------------------------
# Patch for iOS - disable OpenCL and OpenGL
# -----------------------------
# Disable OpenCL Apple auto-detection
sed -i '' 's/#if !defined(FF_HAVE_OPENCL) && defined(__APPLE__) && defined(MAC_OS_X_VERSION_10_15)/#if 0 \/* disabled for iOS *\//' "$BUILD_DIR/src/detection/opencl/opencl.c"

# Disable OpenGL Apple include (iOS doesn't have OpenGL.framework)
sed -i '' 's/#elif __APPLE__/#elif 0 \/* disabled for iOS *\//' "$BUILD_DIR/src/detection/opengl/opengl_shared.c"

# Disable system() call which is unavailable on iOS
sed -i '' 's/if (system(unsafe_yyjson_get_str(val)) < 0)/if (0 \/* system() unavailable on iOS *\/)/' "$BUILD_DIR/src/options/general.c"

# Disable kext manager (not available on iOS) - make it use the fallback
sed -i '' 's/#elif __APPLE__/#elif 0 \/* disabled for iOS - no KextManager *\//' "$BUILD_DIR/src/util/kmod.c"

# Stub out netif_apple.c (net/route.h not available on iOS)
cat >"$BUILD_DIR/src/common/netif/netif_apple.c" <<'EOFSTUB'
#include "netif.h"
#include "common/io/io.h"

// iOS stub - net/route.h is not available
bool ffNetifGetDefaultRouteImpl(FFstrbuf* defaultRoute, const char* ifNameHint) {
    (void)ifNameHint;
    ffStrbufClear(defaultRoute);
    return false;
}
EOFSTUB

# Stub out processing_linux.c (sys/user.h not available on iOS)
cat >"$BUILD_DIR/src/common/processing_linux.c" <<'EOFSTUB'
#include "processing.h"
#include "common/io/io.h"
#include <unistd.h>
#include <signal.h>
#include <spawn.h>
#include <sys/wait.h>

extern char** environ;

const char* ffProcessSpawn(char* const argv[], bool useStdErr, FFProcessHandle* outHandle)
{
    int pipes[2];
    if (pipe(pipes))
        return "pipe() failed";

    pid_t pid;
    posix_spawn_file_actions_t actions;
    posix_spawn_file_actions_init(&actions);
    posix_spawn_file_actions_addclose(&actions, pipes[0]);
    posix_spawn_file_actions_adddup2(&actions, pipes[1], useStdErr ? STDERR_FILENO : STDOUT_FILENO);
    posix_spawn_file_actions_addclose(&actions, pipes[1]);

    int result = posix_spawnp(&pid, argv[0], &actions, NULL, argv, environ);
    posix_spawn_file_actions_destroy(&actions);

    close(pipes[1]);

    if (result != 0)
    {
        close(pipes[0]);
        return "posix_spawnp() failed";
    }

    outHandle->pid = pid;
    outHandle->pipeRead = pipes[0];
    return NULL;
}

const char* ffProcessReadOutput(FFProcessHandle* handle, FFstrbuf* buffer)
{
    if (handle->pid <= 0)
        return "Invalid process";

    ffStrbufClear(buffer);
    char buf[4096];
    ssize_t nRead;
    while ((nRead = read(handle->pipeRead, buf, sizeof(buf))) > 0)
        ffStrbufAppendNS(buffer, (uint32_t)nRead, buf);

    close(handle->pipeRead);
    handle->pipeRead = -1;

    int status = 0;
    waitpid(handle->pid, &status, 0);
    handle->pid = 0;

    ffStrbufTrimRight(buffer, '\n');
    return NULL;
}

const char* ffProcessGetBasicInfoLinux(pid_t pid, FFstrbuf* name, pid_t* ppid, int32_t* tty)
{
    (void)pid;
    ffStrbufSetS(name, "unknown");
    if (ppid) *ppid = 0;
    if (tty) *tty = -1;
    return "Not supported on iOS";
}
EOFSTUB

# Stub out battery_apple.c (IOKit power management not available on iOS)
cat >"$BUILD_DIR/src/detection/battery/battery_apple.c" <<'EOFSTUB'
#include "battery.h"

// iOS stub - IOKit power management headers not available
const char* ffDetectBattery(FFBatteryOptions* options, FFlist* results)
{
    (void)options;
    (void)results;
    return "Battery detection not supported on iOS";
}
EOFSTUB

# Stub out bluetooth_apple.m (IOBluetooth not available on iOS)
cat >"$BUILD_DIR/src/detection/bluetooth/bluetooth_apple.m" <<'EOFSTUB'
#include "bluetooth.h"

// iOS stub - IOBluetooth not available
const char* ffDetectBluetooth(FFBluetoothOptions* options, FFlist* devices)
{
    (void)options;
    (void)devices;
    return "Bluetooth detection not supported on iOS";
}
EOFSTUB

# Stub out bluetoothradio_apple.m
cat >"$BUILD_DIR/src/detection/bluetoothradio/bluetoothradio_apple.m" <<'EOFSTUB'
#include "bluetoothradio.h"

// iOS stub - IOBluetooth not available
const char* ffDetectBluetoothRadio(FFlist* devices)
{
    (void)devices;
    return "Bluetooth radio detection not supported on iOS";
}
EOFSTUB

# Stub out brightness_apple.c (DisplayServices not available on iOS)
cat >"$BUILD_DIR/src/detection/brightness/brightness_apple.c" <<'EOFSTUB'
#include "brightness.h"

// iOS stub - DisplayServices not available
const char* ffDetectBrightness(FFBrightnessOptions* options, FFlist* result)
{
    (void)options;
    (void)result;
    return "Brightness detection not supported on iOS";
}
EOFSTUB

# Stub out media_apple.m (MediaRemote not available on iOS)
cat >"$BUILD_DIR/src/detection/media/media_apple.m" <<'EOFSTUB'
#include "media.h"

// iOS stub - MediaRemote not available
void ffDetectMediaImpl(FFMediaResult* media, bool saveCover)
{
    (void)media;
    (void)saveCover;
    // No-op on iOS
}
EOFSTUB

# Stub out wifi_apple.m (CoreWLAN not available on iOS)
cat >"$BUILD_DIR/src/detection/wifi/wifi_apple.m" <<'EOFSTUB'
#include "wifi.h"

// iOS stub - CoreWLAN not available
const char* ffDetectWifi(FFlist* result)
{
    (void)result;
    return "WiFi detection not supported on iOS";
}
EOFSTUB

# Stub out opengl_apple.c
cat >"$BUILD_DIR/src/detection/opengl/opengl_apple.c" <<'EOFSTUB'
#include "opengl.h"

// iOS stub - OpenGL not available
const char* ffDetectOpenGL(FFOpenGLOptions* options, FFOpenGLResult* result)
{
    (void)options;
    (void)result;
    return "OpenGL detection not supported on iOS";
}
EOFSTUB

# Stub out dns_apple.c (SCDynamicStore not available on iOS)
cat >"$BUILD_DIR/src/detection/dns/dns_apple.c" <<'EOFSTUB'
#include "dns.h"

// iOS stub - SCDynamicStore not available
const char* ffDetectDNS(FFDNSOptions* options, FFlist* results)
{
    (void)options;
    (void)results;
    return "DNS detection not supported on iOS";
}
EOFSTUB

# Stub out physicaldisk_apple.c (IOBSD not available on iOS)
cat >"$BUILD_DIR/src/detection/physicaldisk/physicaldisk_apple.c" <<'EOFSTUB'
#include "physicaldisk.h"

// iOS stub - IOKit/IOBSD not available
const char* ffDetectPhysicalDisk(FFlist* result, FFPhysicalDiskOptions* options)
{
    (void)result;
    (void)options;
    return "Physical disk detection not supported on iOS";
}
EOFSTUB

# Stub out diskio_apple.c (IOBSD not available on iOS)
cat >"$BUILD_DIR/src/detection/diskio/diskio_apple.c" <<'EOFSTUB'
#include "diskio.h"

// iOS stub - IOKit/IOBSD not available
const char* ffDiskIOGetIoCounters(FFlist* result, FFDiskIOOptions* options)
{
    (void)result;
    (void)options;
    return "Disk IO counters not supported on iOS";
}
EOFSTUB

# Stub out displayserver_apple.c (CoreGraphics display APIs not available on iOS)
cat >"$BUILD_DIR/src/detection/displayserver/displayserver_apple.c" <<'EOFSTUB'
#include "displayserver.h"

// iOS stub - CGDirectDisplay not available
void ffConnectDisplayServerImpl(FFDisplayServerResult* ds)
{
    (void)ds;
    // No-op on iOS
}
EOFSTUB

# Stub out font_apple.m (AppKit not available on iOS)
cat >"$BUILD_DIR/src/detection/font/font_apple.m" <<'EOFSTUB'
#include "font.h"

// iOS stub - AppKit not available
const char* ffDetectFontImpl(FFFontResult* result)
{
    (void)result;
    return "Font detection not supported on iOS";
}
EOFSTUB

# Stub out sound_apple.c (CoreAudio not fully available on iOS)
cat >"$BUILD_DIR/src/detection/sound/sound_apple.c" <<'EOFSTUB'
#include "sound.h"

// iOS stub - CoreAudio/AudioToolbox limited on iOS
const char* ffDetectSound(FFlist* devices)
{
    (void)devices;
    return "Sound detection not supported on iOS";
}
EOFSTUB

# Stub out gpu_apple.c (IOKit/graphics not available on iOS)
cat >"$BUILD_DIR/src/detection/gpu/gpu_apple.c" <<'EOFSTUB'
#include "gpu.h"

// iOS stub - IOGraphicsLib not available
const char* ffDetectGPUImpl(const FFGPUOptions* options, FFlist* gpus)
{
    (void)options;
    (void)gpus;
    return "GPU detection not supported on iOS";
}
EOFSTUB

# Stub out gpu_apple.m (Metal/KextManager not available on iOS the same way)
cat >"$BUILD_DIR/src/detection/gpu/gpu_apple.m" <<'EOFSTUB'
#include "gpu.h"

// iOS stub - Metal/KextManager limited
const char* ffGpuDetectDriverVersion(FFlist* gpus)
{
    (void)gpus;
    return "GPU driver version not supported on iOS";
}

const char* ffGpuDetectMetal(FFlist* gpus)
{
    (void)gpus;
    return "Metal GPU detection not supported on iOS";
}
EOFSTUB

# Stub out host_apple.c (IOKit registry access limited on iOS)
cat >"$BUILD_DIR/src/detection/host/host_apple.c" <<'EOFSTUB'
#include "host.h"
#include <sys/sysctl.h>
#include <string.h>

// iOS partial implementation
const char* ffDetectHost(FFHostResult* host)
{
    char model[256];
    size_t len = sizeof(model);
    if (sysctlbyname("hw.machine", model, &len, NULL, 0) == 0)
        ffStrbufAppendS(&host->name, model);
    return NULL;
}
EOFSTUB

# Stub out tpm_apple.c (TPM not available on iOS)
cat >"$BUILD_DIR/src/detection/tpm/tpm_apple.c" <<'EOFSTUB'
#include "tpm.h"

// iOS stub - TPM not available
const char* ffDetectTPM(FFTPMResult* result)
{
    (void)result;
    return "TPM not supported on iOS";
}
EOFSTUB

# Stub out bios_apple.c (IOKit registry for BIOS info not available on iOS)
cat >"$BUILD_DIR/src/detection/bios/bios_apple.c" <<'EOFSTUB'
#include "bios.h"

// iOS stub - BIOS info not available
const char* ffDetectBios(FFBiosResult* bios)
{
    (void)bios;
    return "BIOS detection not supported on iOS";
}
EOFSTUB

# Stub out board_apple.c (IOKit registry for board info not available on iOS)
cat >"$BUILD_DIR/src/detection/board/board_apple.c" <<'EOFSTUB'
#include "board.h"

// iOS stub - Board info not available
const char* ffDetectBoard(FFBoardResult* result)
{
    (void)result;
    return "Board detection not supported on iOS";
}
EOFSTUB

# Stub out keyboard_apple.c (IOKit HID not available on iOS)
cat >"$BUILD_DIR/src/detection/keyboard/keyboard_apple.c" <<'EOFSTUB'
#include "keyboard.h"

// iOS stub - IOKit HID not available
const char* ffDetectKeyboard(FFlist* devices)
{
    (void)devices;
    return "Keyboard detection not supported on iOS";
}
EOFSTUB

# Stub out mouse_apple.c (IOKit HID not available on iOS)
cat >"$BUILD_DIR/src/detection/mouse/mouse_apple.c" <<'EOFSTUB'
#include "mouse.h"

// iOS stub - IOKit HID not available
const char* ffDetectMouse(FFlist* devices)
{
    (void)devices;
    return "Mouse detection not supported on iOS";
}
EOFSTUB

# Stub out gamepad_apple.c (IOKit HID not available on iOS)
cat >"$BUILD_DIR/src/detection/gamepad/gamepad_apple.c" <<'EOFSTUB'
#include "gamepad.h"

// iOS stub - IOKit HID not available
const char* ffDetectGamepad(FFlist* devices)
{
    (void)devices;
    return "Gamepad detection not supported on iOS";
}
EOFSTUB

# Stub out poweradapter_apple.c (IOKit PS not available on iOS)
cat >"$BUILD_DIR/src/detection/poweradapter/poweradapter_apple.c" <<'EOFSTUB'
#include "poweradapter.h"

// iOS stub - IOKit power not available
const char* ffDetectPowerAdapter(FFlist* results)
{
    (void)results;
    return "Power adapter detection not supported on iOS";
}
EOFSTUB

# Stub out localip_linux.c (net/if_media.h not available on iOS)
cat >"$BUILD_DIR/src/detection/localip/localip_linux.c" <<'EOFSTUB'
#include "localip.h"

// iOS stub - if_media not available
const char* ffDetectLocalIps(const FFLocalIpOptions* options, FFlist* results)
{
    (void)options;
    (void)results;
    return "Local IP detection not supported on iOS";
}
EOFSTUB

# Stub out netio_apple.c (net/if_mib.h not available on iOS)
cat >"$BUILD_DIR/src/detection/netio/netio_apple.c" <<'EOFSTUB'
#include "netio.h"

// iOS stub - if_mib not available
const char* ffNetIOGetIoCounters(FFlist* result, FFNetIOOptions* options)
{
    (void)result;
    (void)options;
    return "Network IO counters not supported on iOS";
}
EOFSTUB

# Stub out camera_apple.m (AVCaptureDeviceTypeExternalUnknown not available on iOS)
cat >"$BUILD_DIR/src/detection/camera/camera_apple.m" <<'EOFSTUB'
#include "camera.h"

// iOS stub - external camera type not available
const char* ffDetectCamera(FFlist* result)
{
    (void)result;
    return "Camera detection not supported on iOS";
}
EOFSTUB

# Stub out osascript.m (AppKit not available on iOS)
cat >"$BUILD_DIR/src/util/apple/osascript.m" <<'EOFSTUB'
#include "osascript.h"

// iOS stub - AppleScript/AppKit not available
bool ffOsascript(const char* input, FFstrbuf* result)
{
    (void)input;
    (void)result;
    return false;
}
EOFSTUB

# Patch FFPlatform_unix.c - replace the entire __APPLE__ include block
sed -i '' 's/#ifdef __APPLE__/#if 0 \/\* disabled for iOS - no libproc *\//' "$BUILD_DIR/src/util/platform/FFPlatform_unix.c"
# Replace Apple's proc_pidpath with a fallback that returns 0 length
sed -i '' 's/int exePathLen = proc_pidpath((int) getpid(), exePath, sizeof(exePath));/size_t exePathLen = 0; \/\* iOS fallback - no proc_pidpath *\//' "$BUILD_DIR/src/util/platform/FFPlatform_unix.c"
# Add sysctl.h include for iOS (needed for other functions)
sed -i '' 's/#include <paths.h>/#include <paths.h>\n#include <sys\/sysctl.h>/' "$BUILD_DIR/src/util/platform/FFPlatform_unix.c"

# Patch CMakeLists.txt to remove macOS-only frameworks for iOS
sed -i '' 's/-framework Cocoa/-framework UIKit/' "$BUILD_DIR/CMakeLists.txt"
sed -i '' 's/-framework CoreWLAN//' "$BUILD_DIR/CMakeLists.txt"
sed -i '' 's/-framework IOBluetooth//' "$BUILD_DIR/CMakeLists.txt"
sed -i '' 's/-framework OpenGL//' "$BUILD_DIR/CMakeLists.txt"
sed -i '' 's/-framework OpenCL//' "$BUILD_DIR/CMakeLists.txt"
sed -i '' 's/-weak_framework DisplayServices//' "$BUILD_DIR/CMakeLists.txt"
sed -i '' 's/-weak_framework MediaRemote//' "$BUILD_DIR/CMakeLists.txt"
sed -i '' 's/-weak_framework CoreDisplay//' "$BUILD_DIR/CMakeLists.txt"

# -----------------------------
# Set cross-compile environment
# -----------------------------
export CC=$(xcrun --sdk iphoneos -f clang)
export CXX=$(xcrun --sdk iphoneos -f clang++)
export CFLAGS="-isysroot $SDKROOT -arch $ARCH -O2"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-isysroot $SDKROOT -arch $ARCH"

# -----------------------------
# Configure CMake
# -----------------------------
mkdir "$BUILD_DIR/source"
cd "$BUILD_DIR/source"
cmake .. \
	-DCMAKE_SYSTEM_NAME=iOS \
	-DCMAKE_SYSTEM_PROCESSOR=arm64 \
	-DCMAKE_OSX_SYSROOT="$SDKROOT" \
	-DCMAKE_OSX_ARCHITECTURES="$ARCH" \
	-DCMAKE_INSTALL_PREFIX=/usr/local \
	-DCMAKE_C_COMPILER="$CC" \
	-DCMAKE_CXX_COMPILER="$CXX" \
	-DCMAKE_C_FLAGS="$CFLAGS" \
	-DCMAKE_CXX_FLAGS="$CXXFLAGS" \
	-DBUILD_SHARED_LIBS=OFF \
	-DENABLE_OPENCL=OFF \
	-DENABLE_VULKAN=OFF \
	-DENABLE_IMAGEMAGICK=OFF \
	-DENABLE_CHAFA=OFF \
	-DENABLE_WORDEXP=OFF

# -----------------------------
# Build and install
# -----------------------------
cmake --build . --target fastfetch

# Manually install the binary to the correct location (not as .app bundle)
mkdir -p "$INSTALL_DIR/var/jb/usr/local/bin"
cp "$BUILD_DIR/source/fastfetch.app/fastfetch" "$INSTALL_DIR/var/jb/usr/local/bin/fastfetch"

# Sign the binary with ldid for jailbroken iOS (ad-hoc signature)
# Create entitlements file
cat >"/tmp/ent.plist" <<'ENTEOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>platform-application</key>
    <true/>
    <key>com.apple.private.security.container-required</key>
    <false/>
</dict>
</plist>
ENTEOF

# Try ldid first (if installed via Homebrew), otherwise use codesign
if command -v ldid &>/dev/null; then
	ldid -S/tmp/ent.plist "$INSTALL_DIR/var/jb/usr/local/bin/fastfetch"
	echo "Signed with ldid"
else
	# Use codesign with ad-hoc signature
	codesign --force --deep --sign - "$INSTALL_DIR/var/jb/usr/local/bin/fastfetch"
	echo "Signed with codesign (ad-hoc). You may need to re-sign with ldid on device."
fi

# Copy presets and other data
mkdir -p "$INSTALL_DIR/var/jb/usr/local/share/fastfetch"
cp -r "$BUILD_DIR/presets" "$INSTALL_DIR/var/jb/usr/local/share/fastfetch/" 2>/dev/null || true

# -----------------------------
# Create Debian structure
# -----------------------------
DEBIAN_DIR="${INSTALL_DIR}/DEBIAN"
mkdir -p "$DEBIAN_DIR"

cat >"$DEBIAN_DIR/control" <<EOF
Package: $PACKAGE_NAME
Version: $PACKAGE_VERSION
Section: utils
Priority: optional
Architecture: iphoneos-arm64
Maintainer: Meow <me@xela.codes>
Depends: bash
Description: Fastfetch built for iOS.
EOF

# -----------------------------
# Build the .deb
# -----------------------------
cd "$INSTALL_DIR"
dpkg-deb --build . "/tmp/${PACKAGE_NAME}_${PACKAGE_VERSION}_iphoneos-arm64.deb"

echo "Done! .deb is at /tmp/${PACKAGE_NAME}_${PACKAGE_VERSION}_iphoneos-arm64.deb"
