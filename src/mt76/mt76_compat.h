/* SPDX-License-Identifier: ISC */
/*
 * Build-time kernel-version guard and compatibility shims for out-of-tree mt76 / MT7902.
 *
 * This source is a snapshot of mainline mt76 from the Linux 7.0 development
 * cycle. It relies on recent kernel interfaces. For Linux 6.12 to 6.15,
 * compatibility shims are provided below (e.g. Airoha NPU offload stubs).
 *
 * See README.md for the supported kernel range and guidance for older kernels.
 */
#ifndef __MT76_COMPAT_H
#define __MT76_COMPAT_H

#include <linux/version.h>

#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 12, 0)
#error "This driver targets Linux 6.12 or newer. Older kernels lack APIs this mt76 snapshot depends on. See README.md."
#endif

#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 16, 0)
#include <linux/errno.h>
#include <linux/types.h>

/*
 * Airoha EN7581 NPU offload header (<linux/soc/airoha/airoha_offload.h>)
 * was introduced in Linux 6.16. For kernels 6.12 - 6.15, define dummy structures
 * and stub functions so mt76 core compiles cleanly.
 */
struct airoha_npu {};
struct airoha_ppe_dev {};

struct airoha_npu_tx_dma_desc {
	u32 dummy[4];
};

struct airoha_npu_rx_dma_desc {
	u32 dummy[4];
};

enum airoha_npu_wlan_set_cmd {
	AIROHA_WLAN_SET_DUMMY
};

enum airoha_npu_wlan_get_cmd {
	AIROHA_WLAN_GET_DUMMY
};

static inline int airoha_npu_wlan_send_msg(struct airoha_npu *npu, int ifindex,
					   enum airoha_npu_wlan_set_cmd cmd,
					   const void *val, size_t len, gfp_t gfp)
{
	return -EOPNOTSUPP;
}

static inline int airoha_npu_wlan_get_msg(struct airoha_npu *npu, int ifindex,
					  enum airoha_npu_wlan_get_cmd cmd,
					  void *val, size_t len, gfp_t gfp)
{
	return -EOPNOTSUPP;
}
#endif /* LINUX_VERSION_CODE < KERNEL_VERSION(6, 16, 0) */

#endif /* __MT76_COMPAT_H */
