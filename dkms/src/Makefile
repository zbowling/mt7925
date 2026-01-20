# SPDX-License-Identifier: GPL-2.0-only
# MT76 MT7925 Out-of-tree DKMS Build Makefile
#
# Builds the MT7925 WiFi driver for out-of-tree/DKMS installation.
# This is a standalone Makefile that doesn't require Kconfig.

# Kernel build directory
KDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

# Enable required features
ccflags-y += -I$(src)
ccflags-y += -I$(src)/mt7925

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

# mt792x-lib module
obj-m += mt792x-lib.o
mt792x-lib-y := mt792x_core.o mt792x_mac.o mt792x_trace.o \
		mt792x_debugfs.o mt792x_dma.o mt792x_acpi_sar.o

CFLAGS_mt792x_trace.o := -I$(src)

# mt7925-common module - built at root level with explicit paths
obj-m += mt7925-common.o
mt7925-common-y := \
	mt7925/mac.o mt7925/mcu.o mt7925/main.o mt7925/init.o mt7925/debugfs.o

# mt7925e PCIe module - built at root level with explicit paths
obj-m += mt7925e.o
mt7925e-y := mt7925/pci.o mt7925/pci_mac.o mt7925/pci_mcu.o

# Build targets
all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	rm -f *.o *.ko *.mod.c *.mod .*.cmd Module.symvers modules.order
	rm -f mt7925/*.o mt7925/*.ko mt7925/*.mod.c mt7925/*.mod mt7925/.*.cmd

modules_install:
	$(MAKE) -C $(KDIR) M=$(PWD) modules_install

.PHONY: all clean modules_install
