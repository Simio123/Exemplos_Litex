# Aponte para a pasta "build" gerada pelo seu script Python
BUILD_DIR=/home/emerson/Desktop/teste/ler_programa_C/build

# Define o caminho real do LiteX no seu ambiente virtual
SOC_DIRECTORY=/home/emerson/litex_workspace/litex/litex/soc

# Importa as configurações geradas pelo LiteX
include $(BUILD_DIR)/software/include/generated/variables.mak
include $(SOC_DIRECTORY)/software/common.mak

OBJECTS = main.o

all: app.bin

app.bin: app.elf
	$(OBJCOPY) -O binary $< $@
	chmod -x $@

# Inclui os mapas de memória atualizados e as bibliotecas cruciais
# Inclui apenas o linker.ld (que já puxa o regions.ld automaticamente)
app.elf: $(OBJECTS)
	$(CC) $(LDFLAGS) \
	-T $(SOC_DIRECTORY)/software/demo/linker.ld \
	-o $@ \
	$(BUILD_DIR)/software/bios/crt0.o \
	$(OBJECTS) \
	-L$(BUILD_DIR)/software/libc -lc \
	-L$(BUILD_DIR)/software/libbase -lbase \
	-L$(BUILD_DIR)/software/libcompiler_rt -lcompiler_rt

%.o: %.c
	$(compile)

clean:
	rm -f *.o *.elf *.bin
