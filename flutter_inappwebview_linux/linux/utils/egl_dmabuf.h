#ifndef FLUTTER_INAPPWEBVIEW_LINUX_UTILS_EGL_DMABUF_H_
#define FLUTTER_INAPPWEBVIEW_LINUX_UTILS_EGL_DMABUF_H_

#ifdef HAVE_WPE_PLATFORM

#include <wpe/wpe-platform.h>

#include <string>

namespace flutter_inappwebview_plugin {

/**
 * Binds the DMA-BUF behind a WPE buffer to the GL_TEXTURE_2D bound in the
 * current context, with no copy.
 *
 * The EGLImage is made on the display of the context that samples it, never
 * on WPE's own: an EGLImage is valid only on the display that made it, and
 * WPE's headless display is not the one Flutter or GTK draws with, so Mesa
 * refuses the bind and the texture stays empty. The image is made once per
 * buffer, kept on the buffer and destroyed with it, since WebKit hands back
 * the same few buffers in turn.
 *
 * Call with a GL context current. On false nothing was bound and [failure]
 * says why: the context is not an EGL one, the display cannot import the
 * buffer (no dma-buf import, an unsupported format or modifier, another GPU),
 * or the bind raised a GL error.
 */
bool BindDmaBufToCurrentTexture(WPEBuffer* buffer, std::string* failure);

}  // namespace flutter_inappwebview_plugin

#endif  // HAVE_WPE_PLATFORM

#endif  // FLUTTER_INAPPWEBVIEW_LINUX_UTILS_EGL_DMABUF_H_
