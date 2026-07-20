#include <stdio.h>
#include <stdlib.h>
#include <generated/csr.h>
#include <libbase/uart.h>

static void delay(int cycles) {
    for (volatile int i = 0; i < cycles; i++);
}

// dest_core: qual dos núcleos (0 ou 1) do roteador de destino deve
// receber o pacote. Vai embutido no bit mais significativo do
// payload de 32 bits (ver LocalMux em router.py).
static void send_packet(uint8_t dest_x, uint8_t dest_y, uint8_t dest_core, uint32_t payload) {
    while (noc_tx_busy_read() == 1);
    uint8_t endereco = (dest_y << 2) | dest_x;
    uint32_t data = (payload & 0x7FFFFFFFUL) | ((uint32_t)(dest_core & 1) << 31);
    noc_tx_dest_write(endereco);
    noc_tx_data_write(data);
    noc_tx_send_write(1);
}

int main(void) {
#ifdef CSR_UART_BASE
    uart_init();
#endif

    uint8_t my_x    = main_noc_coords_read() & 0x0F;
    uint8_t my_y    = (main_noc_coords_read() >> 4) & 0x0F;
    uint8_t my_core = main_core_id_read() & 0x1;

    // Só o roteador (0,0), núcleo 0, tem UART real nesta simulação.
    uint8_t observavel = (my_x == 0 && my_y == 0 && my_core == 0);

    uint32_t msg_count = 1;
    uint32_t tx_timer = 0;
    
    // Define o atraso desejado entre envios
    const uint32_t TX_INTERVAL = 300000; 

    delay(100000); // tempo para todos os núcleos terminarem o boot

    while (1) {
        // --- 1. RECEPTOR: Tenta esvaziar a NoC o mais rápido possível ---
        if (noc_rx_valid_read() == 1) {
            uint32_t dado = noc_rx_data_read();
            noc_rx_ack_write(1);

            if (observavel) {
                uint8_t  from_x    = (dado >> 24) & 0xF;
                uint8_t  from_y    = (dado >> 20) & 0xF;
                uint8_t  from_core = (dado >> 16) & 0xF;
                uint32_t seq       = dado & 0xFFFF;
                printf("-> [0,0,c0] pacote de tile(%u,%u) core%u, seq=%lu (raw=0x%lx)\n",
                       from_x, from_y, from_core,
                       (unsigned long)seq, (unsigned long)dado);
            }
        }

        // --- 2. GERADOR DE PACOTES: Só envia quando for a hora ---
        tx_timer++;
        if (tx_timer >= TX_INTERVAL) {
            tx_timer = 0; // Reseta o timer
            
            if (observavel) {
                send_packet(1, 1, 1, 0xE0000000UL | (msg_count & 0xFFFF));
            } else {
                uint32_t payload = ((uint32_t)my_x    << 24)
                                  | ((uint32_t)my_y    << 20)
                                  | ((uint32_t)my_core << 16)
                                  | (msg_count & 0xFFFF);
                send_packet(0, 0, 0, payload);
            }
            msg_count++;
        }
    }
    return 0;
}
