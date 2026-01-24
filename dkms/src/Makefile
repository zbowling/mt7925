# SPDX-License-Identifier: GPL-2.0-only
# MT76 MT7925/MT7921 Out-of-tree DKMS Build Makefile
#
# Builds the MT7925 and MT7921 WiFi drivers for out-of-tree/DKMS installation.
# This is a standalone Makefile that doesn't require Kconfig.
#
# MT7921 is included because mt792x-lib is shared between both drivers.
# Building only mt7925 would cause ABI mismatch for mt7921 users.

# Kernel build directory
KDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

# Enable required features
ccflags-y += -I$(src)
ccflags-y += -I$(src)/mt7925
ccflags-y += -I$(src)/mt7921

# Module definitions

# mt76 core module
obj-m += mt76.o
mt76-y := \
	mmio.o util.o trace.o dma.o mac80211.o debugfs.o eeprom.o \
	tx.o agg-rx.o mcu.o wed.o scan.o channel.o pci.o

CFLAGS_trace.o := -I$(src)

# mt76-connac-lib module
obj-m += mt76-connac-lib.o
mt76-connac-lib-y := mt76_connac_mcu.o mt76_connac_mac.o mt76_connac3_mac.o

# mt792x-lib module (shared between mt7921 and mt7925)
obj-m += mt792x-lib.o
mt792x-lib-y := mt792x_core.o mt792x_mac.o mt792x_trace.o \
		mt792x_debugfs.o mt792x_dma.o mt792x_acpi_sar.o

CFLAGS_mt792x_trace.o := -I$(src)

# ============================================================
# MT7921 modules (included for ABI compatibility with mt792x-lib)
# ============================================================

# mt7921-common module
obj-m += mt7921-common.o
mt7921-common-y := \
	mt7921/mac.o mt7921/mcu.o mt7921/main.o mt7921/init.o mt7921/debugfs.o

# mt7921e PCIe module
obj-m += mt7921e.o
mt7921e-y := mt7921/pci.o mt7921/pci_mac.o mt7921/pci_mcu.o

# mt7921s SDIO module
obj-m += mt7921s.o
mt7921s-y := mt7921/sdio.o mt7921/sdio_mac.o mt7921/sdio_mcu.o

# mt7921u USB module
obj-m += mt7921u.o
mt7921u-y := mt7921/usb.o

# ============================================================
# MT7925 modules
# ============================================================

# mt7925-common module
obj-m += mt7925-common.o
mt7925-common-y := \
	mt7925/mac.o mt7925/mcu.o mt7925/main.o mt7925/init.o mt7925/debugfs.o

# mt7925e PCIe module
obj-m += mt7925e.o
mt7925e-y := mt7925/pci.o mt7925/pci_mac.o mt7925/pci_mcu.o

# Build targets
all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	rm -f *.o *.ko *.mod.c *.mod .*.cmd Module.symvers modules.order
	rm -f mt7925/*.o mt7925/*.ko mt7925/*.mod.c mt7925/*.mod mt7925/.*.cmd
	rm -f mt7921/*.o mt7921/*.ko mt7921/*.mod.c mt7921/*.mod mt7921/.*.cmd

modules_install:
	$(MAKE) -C $(KDIR) M=$(PWD) modules_install

.PHONY: all clean modules_install
