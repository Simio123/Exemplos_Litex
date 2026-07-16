BUILD_DIR ?= ../..
SRC_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

include $(BUILD_DIR)/software/include/generated/variables.mak
include $(SOC_DIRECTORY)/software/common.mak

# Adicionamos o crt0.o na NOSSA lista de objetos para compilar junto com o main
OBJECTS = crt0.o main.o

all: noc_app.bin

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@
	chmod -x $@

noc_app.elf: $(OBJECTS)
	$(CC) $(LDFLAGS) \
		-T $(SOC_DIRECTORY)/software/demo/linker.ld \
		-o $@ \
		$(OBJECTS) \
		-L$(BUILD_DIR)/software/libc -lc \
		-L$(BUILD_DIR)/software/libbase -lbase \
		-L$(BUILD_DIR)/software/libcompiler_rt -lcompiler_rt

# A REGRA DE OURO: Compilamos o Assembly de boot direto da fonte do processador!
crt0.o: $(CPU_DIRECTORY)/crt0.S
	$(CC) $(CFLAGS) -c $< -o $@

main.o: $(SRC_DIR)main.c
	$(compile)
