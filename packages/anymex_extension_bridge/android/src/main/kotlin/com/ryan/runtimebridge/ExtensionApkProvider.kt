package com.ryan.runtimebridge

import androidx.core.content.FileProvider

/** A distinct manifest identity prevents the host's general FileProvider from
 * replacing the extension install authority during Android manifest merging. */
class ExtensionApkProvider : FileProvider()
