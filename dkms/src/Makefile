# SPDX-License-Identifier: GPL-2.0-only
# MT76 MT7925 Out-of-tree DKMS Build Makefile

KDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

# Auto-detect clang-built kernels and use LLVM toolchain
# Check for CONFIG_CC_IS_CLANG in kernel config
CLANG_FLAGS :=
ifneq ($(wildcard $(KDIR)/.config),)
  ifneq ($(shell grep -s "CONFIG_CC_IS_CLANG=y" $(KDIR)/.config),)
    $(info Detected clang-built kernel, using LLVM toolchain)
    CLANG_FLAGS := CC=clang LD=ld.lld LLVM=1
  endif
endif

# Include paths
ccflags-y += -I$(src)

# Module definitions - core mt76
obj-m += mt76.o
mt76-y := mmio.o util.o trace.o dma.o mac80211.o debugfs.o eeprom.o \
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

# mt7925-common module (built from mt7925/ subdir files)
obj-m += mt7925-common.o
mt7925-common-y := mt7925/mac.o mt7925/mcu.o mt7925/main.o mt7925/init.o mt7925/debugfs.o

# mt7925e PCIe module
obj-m += mt7925e.o
mt7925e-y := mt7925/pci.o mt7925/pci_mac.o mt7925/pci_mcu.o

# Build targets
all:
	$(MAKE) -C $(KDIR) M=$(PWD) $(CLANG_FLAGS) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	rm -f *.o *.ko *.mod.c *.mod .*.cmd Module.symvers modules.order
	rm -f mt7925/*.o mt7925/.*.cmd

install:
	$(MAKE) -C $(KDIR) M=$(PWD) $(CLANG_FLAGS) modules_install
	depmod -a

unload:
	-rmmod mt7925e 2>/dev/null || true
	-rmmod mt7925-common 2>/dev/null || true
	-rmmod mt792x-lib 2>/dev/null || true
	-rmmod mt76-connac-lib 2>/dev/null || true
	-rmmod mt76 2>/dev/null || true

load: unload
	insmod mt76.ko
	insmod mt76-connac-lib.ko
	insmod mt792x-lib.ko
	insmod mt7925-common.ko
	insmod mt7925e.ko

.PHONY: all clean install unload load
