/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * MT76 Kernel Compatibility Header
 * Handles API differences across kernel versions for out-of-tree builds
 */

#ifndef __MT76_COMPAT_H
#define __MT76_COMPAT_H

#include <linux/version.h>

/*
 * Kernel version detection macros
 * Use these to conditionally compile code for different kernel versions
 */

/* Enable DKMS-specific debugging features:
 * - MT76_STATE_ROC_ABORT for async ROC abort
 * - ROC rate limiting/backoff mechanism
 * - Extra dev_info() logging throughout
 * Override via compiler flag: -DMT76_DKMS_DEBUG_FEATURES=0
 */
#ifndef MT76_DKMS_DEBUG_FEATURES
#define MT76_DKMS_DEBUG_FEATURES 1
#endif

/* 6.19+ has refactored regulatory code in regd.c */
#define MT76_KERNEL_HAS_REGD_REFACTOR (LINUX_VERSION_CODE >= KERNEL_VERSION(6, 19, 0))

/* 6.18+ has MLO power management improvements */
#define MT76_KERNEL_HAS_MLO_PM (LINUX_VERSION_CODE >= KERNEL_VERSION(6, 18, 0))

/* EHT puncturing support (kernel 6.5+) */
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 5, 0)
#define MT76_HAS_EHT_PUNCTURING 1
#else
#define MT76_HAS_EHT_PUNCTURING 0
#endif

/* CSA in chanctx mode (available in all supported kernels) */
#define MT76_HAS_CSA_SUPPORT 1

/*
 * struct ieee80211_mgmt action-frame layout
 * - 7.1 flattened the nested action union: u.action.u.addba_req became
 *   u.action.addba_req, and action_code is read via u.action.action_code
 * - 7.0 and earlier keep the nested form u.action.u.addba_req.{action_code,capab}
 */
#if LINUX_VERSION_CODE >= KERNEL_VERSION(7, 1, 0)
#define MT76_MGMT_ACTION_CODE(mgmt) ((mgmt)->u.action.action_code)
#define MT76_MGMT_ADDBA_REQ(mgmt)   ((mgmt)->u.action.addba_req)
#else
#define MT76_MGMT_ACTION_CODE(mgmt) ((mgmt)->u.action.u.addba_req.action_code)
#define MT76_MGMT_ADDBA_REQ(mgmt)   ((mgmt)->u.action.u.addba_req)
#endif

/*
 * ieee80211_iterate_active_interfaces() callback signature
 * Stable across 6.8-6.19+
 */

/*
 * cfg80211_get_chandef_type() - consistent API across 6.8+
 */

/*
 * Regulatory domain handling
 * - 6.18 and earlier: mt7925_regd_update() in init.c
 * - 6.19+: mt7925_mcu_regd_update() and mt7925_regd_change() in regd.c
 *
 * The DKMS source uses the 6.18 approach which is self-contained
 * and works across all supported kernel versions.
 */

/*
 * mac80211 channel context changes
 * - Channel context assignment APIs are stable across 6.8-6.19+
 */

/*
 * PCI power management
 * - pci_set_power_state() and related APIs stable
 * - Runtime PM APIs unchanged
 */

/*
 * Firmware loading
 * - request_firmware() API unchanged across supported versions
 */

/*
 * DMA mapping
 * - dma_map_single/page APIs stable
 * - No changes needed for 6.8-6.19+
 */

#endif /* __MT76_COMPAT_H */
