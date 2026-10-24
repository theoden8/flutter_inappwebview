#include "egl_dmabuf.h"

#ifdef HAVE_WPE_PLATFORM

#include <epoxy/egl.h>
#include <epoxy/gl.h>

#include <array>
#include <cstdio>
#include <vector>

namespace flutter_inappwebview_plugin {

namespace {

// DRM_FORMAT_MOD_INVALID (drm_fourcc.h): the buffer names no modifier.
constexpr guint64 kInvalidModifier = 0x00ffffffffffffffULL;

// GL_CONTEXT_LOST repeats until the context is reset, so draining stops.
constexpr int kMaxStaleGlErrors = 16;

struct BufferImage {
  EGLDisplay display;
  EGLImageKHR image;
};

GQuark BufferImageQuark() {
  static GQuark quark = g_quark_from_static_string("flutter-inappwebview-egl-image");
  return quark;
}

void DestroyBufferImage(gpointer data) {
  auto* entry = static_cast<BufferImage*>(data);
  eglDestroyImageKHR(entry->display, entry->image);
  delete entry;
}

std::string Hex(unsigned int code) {
  char text[16];
  std::snprintf(text, sizeof(text), "0x%04x", code);
  return text;
}

EGLImageKHR CreateImage(WPEBufferDMABuf* buffer, EGLDisplay display, std::string* failure) {
  if (!epoxy_has_egl_extension(display, "EGL_EXT_image_dma_buf_import")) {
    *failure = "the EGL display has no EGL_EXT_image_dma_buf_import";
    return EGL_NO_IMAGE_KHR;
  }

  static constexpr std::array<std::array<EGLint, 5>, 4> kPlaneNames = {{
      {EGL_DMA_BUF_PLANE0_FD_EXT, EGL_DMA_BUF_PLANE0_OFFSET_EXT, EGL_DMA_BUF_PLANE0_PITCH_EXT,
       EGL_DMA_BUF_PLANE0_MODIFIER_LO_EXT, EGL_DMA_BUF_PLANE0_MODIFIER_HI_EXT},
      {EGL_DMA_BUF_PLANE1_FD_EXT, EGL_DMA_BUF_PLANE1_OFFSET_EXT, EGL_DMA_BUF_PLANE1_PITCH_EXT,
       EGL_DMA_BUF_PLANE1_MODIFIER_LO_EXT, EGL_DMA_BUF_PLANE1_MODIFIER_HI_EXT},
      {EGL_DMA_BUF_PLANE2_FD_EXT, EGL_DMA_BUF_PLANE2_OFFSET_EXT, EGL_DMA_BUF_PLANE2_PITCH_EXT,
       EGL_DMA_BUF_PLANE2_MODIFIER_LO_EXT, EGL_DMA_BUF_PLANE2_MODIFIER_HI_EXT},
      {EGL_DMA_BUF_PLANE3_FD_EXT, EGL_DMA_BUF_PLANE3_OFFSET_EXT, EGL_DMA_BUF_PLANE3_PITCH_EXT,
       EGL_DMA_BUF_PLANE3_MODIFIER_LO_EXT, EGL_DMA_BUF_PLANE3_MODIFIER_HI_EXT},
  }};

  guint32 planes = wpe_buffer_dma_buf_get_n_planes(buffer);
  if (planes == 0 || planes > kPlaneNames.size()) {
    *failure = "the buffer has " + std::to_string(planes) + " planes";
    return EGL_NO_IMAGE_KHR;
  }

  // As WPE's own import does: a modifier is passed only where the buffer
  // names one and the display takes it.
  guint64 modifier = wpe_buffer_dma_buf_get_modifier(buffer);
  bool with_modifier =
      modifier != kInvalidModifier &&
      epoxy_has_egl_extension(display, "EGL_EXT_image_dma_buf_import_modifiers");

  WPEBuffer* base = WPE_BUFFER(buffer);
  std::vector<EGLint> attributes = {
      EGL_WIDTH,
      wpe_buffer_get_width(base),
      EGL_HEIGHT,
      wpe_buffer_get_height(base),
      EGL_LINUX_DRM_FOURCC_EXT,
      static_cast<EGLint>(wpe_buffer_dma_buf_get_format(buffer)),
  };
  for (guint32 plane = 0; plane < planes; plane++) {
    const auto& names = kPlaneNames[plane];
    attributes.insert(attributes.end(),
                      {names[0], wpe_buffer_dma_buf_get_fd(buffer, plane), names[1],
                       static_cast<EGLint>(wpe_buffer_dma_buf_get_offset(buffer, plane)),
                       names[2],
                       static_cast<EGLint>(wpe_buffer_dma_buf_get_stride(buffer, plane))});
    if (with_modifier) {
      attributes.insert(attributes.end(),
                        {names[3], static_cast<EGLint>(modifier & 0xffffffff), names[4],
                         static_cast<EGLint>(modifier >> 32)});
    }
  }
  attributes.push_back(EGL_NONE);

  EGLImageKHR image = eglCreateImageKHR(display, EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT,
                                        nullptr, attributes.data());
  if (image == EGL_NO_IMAGE_KHR) {
    *failure = "eglCreateImageKHR failed with EGL error " + Hex(eglGetError());
  }
  return image;
}

}  // namespace

bool BindDmaBufToCurrentTexture(WPEBuffer* buffer, std::string* failure) {
  if (!WPE_IS_BUFFER_DMA_BUF(buffer)) {
    *failure = "the buffer is not a DMA-BUF";
    return false;
  }
  if (eglGetCurrentContext() == EGL_NO_CONTEXT) {
    *failure = "the current GL context is not an EGL one";
    return false;
  }
  if (!epoxy_has_gl_extension("GL_OES_EGL_image")) {
    *failure = "the GL context has no GL_OES_EGL_image";
    return false;
  }

  EGLDisplay display = eglGetCurrentDisplay();
  auto* entry = static_cast<BufferImage*>(g_object_get_qdata(G_OBJECT(buffer), BufferImageQuark()));
  if (entry == nullptr || entry->display != display) {
    EGLImageKHR image = CreateImage(WPE_BUFFER_DMA_BUF(buffer), display, failure);
    if (image == EGL_NO_IMAGE_KHR) {
      return false;
    }
    entry = new BufferImage{display, image};
    g_object_set_qdata_full(G_OBJECT(buffer), BufferImageQuark(), entry, DestroyBufferImage);
  }

  for (int i = 0; i < kMaxStaleGlErrors && glGetError() != GL_NO_ERROR; i++) {
  }
  glEGLImageTargetTexture2DOES(GL_TEXTURE_2D, static_cast<GLeglImageOES>(entry->image));
  GLenum error = glGetError();
  if (error != GL_NO_ERROR) {
    *failure = "glEGLImageTargetTexture2DOES failed with GL error " + Hex(error);
    return false;
  }
  return true;
}

}  // namespace flutter_inappwebview_plugin

#endif  // HAVE_WPE_PLATFORM
