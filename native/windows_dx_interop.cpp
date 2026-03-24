// Copyright (c) 2025 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

#include "jni_util.h"

#include "include/base/cef_logging.h"

#include <d3d11.h>
#include <iomanip>
#include <wrl/client.h>

namespace {

using Microsoft::WRL::ComPtr;

}  // namespace

JNIEXPORT jlong JNICALL
Java_net_ccbluex_liquidbounce_mcef_cef_MCEFWindowsDxInterop_nCreateD3DDevice(
    JNIEnv*,
    jclass) {
  ComPtr<ID3D11Device> device;
  ComPtr<ID3D11DeviceContext> context;
  D3D_FEATURE_LEVEL feature_level = D3D_FEATURE_LEVEL_11_0;

  static constexpr D3D_FEATURE_LEVEL feature_levels[] = {
      D3D_FEATURE_LEVEL_11_0,
  };

  const HRESULT hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE,
                                       nullptr,
                                       D3D11_CREATE_DEVICE_BGRA_SUPPORT,
                                       feature_levels,
                                       ARRAYSIZE(feature_levels),
                                       D3D11_SDK_VERSION, &device,
                                       &feature_level, &context);
  if (FAILED(hr)) {
    LOG(ERROR) << "Failed to create D3D11 device for DX interop. hr=0x"
               << std::hex << hr;
    return 0;
  }

  LOG(INFO) << "Created D3D11 device for DX interop at feature level 0x"
            << std::hex << static_cast<int>(feature_level);
  return reinterpret_cast<jlong>(device.Detach());
}

JNIEXPORT jlong JNICALL
Java_net_ccbluex_liquidbounce_mcef_cef_MCEFWindowsDxInterop_nOpenSharedTexture(
    JNIEnv*,
    jclass,
    jlong d3dDevice,
    jlong sharedTextureHandle) {
  if (d3dDevice == 0 || sharedTextureHandle == 0) {
    return 0;
  }

  auto* device = reinterpret_cast<ID3D11Device*>(d3dDevice);
  ComPtr<ID3D11Texture2D> texture;
  const HRESULT hr = device->OpenSharedResource(
      reinterpret_cast<HANDLE>(sharedTextureHandle),
      __uuidof(ID3D11Texture2D),
      reinterpret_cast<void**>(texture.GetAddressOf()));
  if (FAILED(hr)) {
    LOG(ERROR) << "Failed to open shared D3D11 texture 0x" << std::hex
               << sharedTextureHandle << ". hr=0x" << hr;
    return 0;
  }

  return reinterpret_cast<jlong>(texture.Detach());
}

JNIEXPORT void JNICALL
Java_net_ccbluex_liquidbounce_mcef_cef_MCEFWindowsDxInterop_nReleaseComObject(
    JNIEnv*,
    jclass,
    jlong comObject) {
  if (comObject == 0) {
    return;
  }

  auto* object = reinterpret_cast<IUnknown*>(comObject);
  object->Release();
}
