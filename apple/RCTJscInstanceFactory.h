/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 */

#pragma once

// Forward-declare the opaque type instead of importing the non-modular
// JSRuntimeFactoryCAPI.h header, which would cause "include of non-modular
// header inside framework module" errors with use_frameworks!.
typedef void *JSRuntimeFactoryRef;

#ifdef __cplusplus
extern "C" {
#endif

JSRuntimeFactoryRef jsrt_create_jsc_factory(void);

#ifdef __cplusplus
}
#endif
