/* SPDX-License-Identifier: ISC */
/*
 * Build-time kernel-version guard for the out-of-tree mt76 / MT7902 driver.
 *
 * This source is a snapshot of mainline mt76 from the Linux 7.0 development
 * cycle. It relies on recent kernel interfaces, including the Airoha offload
 * header (<linux/soc/airoha/airoha_offload.h>) pulled in by mt76.h and recent
 * mac80211/cfg80211 APIs. Building against older kernels fails with
 * hard-to-read errors, so the guard below reports a clear message instead.
 *
 * See README.md for the supported kernel range and guidance for older kernels.
 */
#ifndef __MT76_COMPAT_H
#define __MT76_COMPAT_H

#include <linux/version.h>

#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 16, 0)
#error "This driver targets Linux 6.16 or newer. Older kernels lack APIs this mt76 snapshot depends on. See README.md."
#endif

#endif /* __MT76_COMPAT_H */
