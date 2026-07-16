#include <stdio.h>
#include <stdlib.h>
#include <generated/csr.h>

// Loop de delay adaptado para o novo clock de 10 MHz
static void delay(int cycles) {
    for (volatile int i = 0; i < cycles; i++);
}

static void send_packet(uint8_t dest_x, uint8_t dest_y, uint32_t data) {
    while (noc_tx_busy_read() == 1); 
    uint8_t endereco = (dest_y << 2) | dest_x;
    noc_tx_dest_write(endereco);
    noc_tx_data_write(data);
    noc_tx_send_write(1); 
}

int main(void) {
    // Lê as coordenadas para saber quem sou eu
    uint8_t my_x = main_noc_coords_read() & 0x0F;
    uint8_t my_y = (main_noc_coords_read() >> 4) & 0x0F;

    uint32_t ping_counter = 1;

    while (1) {
        // Apenas o nó 0 vai falar diretamente no terminal físico
        if (my_x == 0 && my_y == 0) {
            printf("\n--- [Node 0,0] Rodando! ---\n");
            
            // Tenta enviar um pacote para o Nó 3 (1,1)
            printf("<- [0,0] Disparando 0x%lx para (1,1)...\n", 0xCAFE0000 + ping_counter);
            send_packet(1, 1, 0xCAFE0000 + ping_counter);
        }

        // Se chegar pacote no roteador local, tratamos
        if (noc_rx_valid_read() == 1) {
            uint32_t dado = noc_rx_data_read();
            noc_rx_ack_write(1); 
            
            if (my_x == 0 && my_y == 0) {
                printf("-> [0,0] *** RECEBEU DA MALHA: 0x%lx ***\n", dado);
            }
        }

        // O Nó 3 (1,1) responde automaticamente de volta para o Nó 0
        if (my_x == 1 && my_y == 1) {
            send_packet(0, 0, 0xBEEF0000 + ping_counter);
        }

        ping_counter++;
        delay(3000000); // Delay aumentado proporcionalmente ao novo clock
    }

    return 0;
}
