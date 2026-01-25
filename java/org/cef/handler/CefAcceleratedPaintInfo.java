// Copyright (c) 2024 The Chromium Embedded Framework Authors. All rights
// reserved. Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

package org.cef.handler;

/**
 * Structure representing shared texture info for accelerated painting.
 */
public class CefAcceleratedPaintInfo {
    /**
     * Shared texture handle. The meaning depends on the platform:
     * - Windows: HANDLE to a texture that can be opened with D3D11 OpenSharedResource
     * - macOS: Not used; todo: IOSurface pointer that can be opened with Metal or OpenGL
     * - Linux: Not used; dmabuf planes are exposed via the plane_* fields
     */
    public long shared_texture_handle = 0;
    
    /**
     * Format of the shared texture.
     */
    public int format = 0;
    
    /**
     * Size information for the shared texture.
     */
    public int width = 0;
    public int height = 0;

    /**
     * Linux-only dmabuf plane count.
     */
    public int plane_count = 0;

    /**
     * Linux-only dmabuf plane file descriptors.
     */
    public int[] plane_fds = null;

    /**
     * Linux-only dmabuf plane strides (bytes per row).
     */
    public int[] plane_strides = null;

    /**
     * Linux-only dmabuf plane offsets.
     */
    public long[] plane_offsets = null;

    /**
     * Linux-only dmabuf plane sizes.
     */
    public long[] plane_sizes = null;

    /**
     * Linux-only dmabuf modifier.
     */
    public long modifier = 0;
    
    public CefAcceleratedPaintInfo() {}
    
    public CefAcceleratedPaintInfo(long shared_texture_handle, int format, int width, int height) {
        this.shared_texture_handle = shared_texture_handle;
        this.format = format;
        this.width = width;
        this.height = height;
    }

    public boolean hasDmaBufPlanes() {
        return plane_count > 0 && plane_fds != null && plane_strides != null && plane_offsets != null;
    }
    
    @Override
    public CefAcceleratedPaintInfo clone() {
        CefAcceleratedPaintInfo clone = new CefAcceleratedPaintInfo(shared_texture_handle, format, width, height);
        clone.plane_count = plane_count;
        clone.modifier = modifier;
        clone.plane_fds = plane_fds != null ? plane_fds.clone() : null;
        clone.plane_strides = plane_strides != null ? plane_strides.clone() : null;
        clone.plane_offsets = plane_offsets != null ? plane_offsets.clone() : null;
        clone.plane_sizes = plane_sizes != null ? plane_sizes.clone() : null;
        return clone;
    }
}
