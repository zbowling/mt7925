# SPDX-License-Identifier: GPL-2.0-only
# MT76 MT7925 Out-of-tree Makefile for DKMS
#
# Builds: mt76.ko, mt76-connac-lib.ko, mt792x-lib.ko, mt7925-common.ko, mt7925e.ko

KDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

# Modules to build (out-of-tree)
obj-m += mt76.o
obj-m += mt76-connac-lib.o
obj-m += mt792x-lib.o
obj-m += mt7925/

# mt76 core module
mt76-y := \
	mmio.o util.o trace.o dma.o mac80211.o debugfs.o eeprom.o \
	tx.o agg-rx.o mcu.o wed.o scan.o channel.o pci.o

# mt76-connac-lib module
mt76-connac-lib-y := mt76_connac_mcu.o mt76_connac_mac.o mt76_connac3_mac.o

# mt792x-lib module
mt792x-lib-y := mt792x_core.o mt792x_mac.o mt792x_trace.o \
		mt792x_debugfs.o mt792x_dma.o

# Include ACPI SAR support if available
mt792x-lib-$(CONFIG_ACPI) += mt792x_acpi_sar.o

# Trace include paths
CFLAGS_trace.o := -I$(src)
CFLAGS_mt792x_trace.o := -I$(src)

# Out-of-tree build targets
all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	rm -f *.o *.ko *.mod.c *.mod .*.cmd modules.order Module.symvers
	rm -f mt7925/*.o mt7925/*.ko mt7925/*.mod.c mt7925/*.mod mt7925/.*.cmd

modules_install:
	$(MAKE) -C $(KDIR) M=$(PWD) modules_install

.PHONY: all clean modules_install
