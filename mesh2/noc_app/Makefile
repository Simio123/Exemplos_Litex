# Importa as variáveis de ambiente geradas pelo LiteX (caminhos e compiladores)
include ../../software/include/generated/variables.mak
# common.mak é quem realmente define CFLAGS/INCLUDES (-I para generated/csr.h,
# libc, libbase, libcompiler_rt etc.) — sem ele o cc compila "no escuro".
include $(SOC_DIRECTORY)/software/common.mak

# Descobre o diretório real onde este Makefile e o seu main.c residem
# (firstword, não lastword: o include acima empilha variables.mak/common.mak
# em MAKEFILE_LIST DEPOIS deste próprio Makefile, então o primeiro elemento
# da lista é sempre este arquivo — o lastword pegaria o último include lido)
REAL_SRC_DIR := $(dir $(abspath $(firstword $(MAKEFILE_LIST))))

# Define os objetos que serão linkados
# crt0.o não fica "solto" no diretório de build de libbase depois de
# virar libbase.a — precisa ser (re)compilado aqui a partir do fonte,
# igual o demo/Makefile original do LiteX faz.
OBJECTS = crt0.o noc_main.o

all: noc_app.bin

# Gera o arquivo binário final aceito pela ROM do nó
%.bin: %.elf
	$(OBJCOPY) -O binary $< $@
	chmod -x $@

crt0.o: $(CPU_DIRECTORY)/crt0.S
	$(CC) $(CFLAGS) -c $< -o $@

# Junta o ponto de boot (crt0.o), o seu código compilado e todas as bibliotecas base do LiteX.
# --start-group/--end-group: deixa o ld resolver dependências circulares
# entre as libs (ex: libbase precisando de printf da libc) não importa
# a ordem, escaneando o grupo quantas vezes for preciso.
noc_app.elf: $(OBJECTS)
	$(CC) $(LDFLAGS) \
		-T $(SOC_DIRECTORY)/software/bios/linker.ld \
		-o $@ \
		$(OBJECTS) \
		-Wl,--start-group \
		-L../libbase -lbase \
		-L../libc -lc \
		-L../libcompiler_rt -lcompiler_rt \
		-Wl,--end-group

# Regra manual pura: Compila o SEU main.c original sem nenhuma interferência de macros ocultas
# IMPORTANTE: main.c precisa estar do lado direito dos ":" como pré-requisito.
# Sem isso, o make considera noc_main.o "sempre atualizado" depois da
# primeira vez que ele existe, e NUNCA recompila de novo mesmo que você
# edite o main.c — só rm -rf build (ou make clean aqui dentro) força.
noc_main.o: $(REAL_SRC_DIR)main.c
	$(CC) $(CFLAGS) $(INCLUDES) -c $(REAL_SRC_DIR)main.c -o noc_main.o

clean:
	rm -f *.o *.elf *.bin
