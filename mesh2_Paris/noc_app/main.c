#include <stdio.h>
#include <stdlib.h>
#include <generated/csr.h>
#include <libbase/uart.h>

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
#ifdef CSR_UART_BASE
    uart_init();
#endif
    printf("\n*** BOOT OK: cheguei no main() ***\n");

    uint8_t my_x = main_noc_coords_read() & 0x0F;
    uint8_t my_y = (main_noc_coords_read() >> 4) & 0x0F;
    uint32_t ping_counter = 1;

    // Trava de segurança para não engarrafar a rede
    uint8_t pronto_para_enviar = 1;

    // Dá um tempinho extra para todos os nós da malha terminarem de dar boot
    delay(100000);

    while (1) {
        // --- INTERAÇÃO PELO TERMINAL (Apenas no Nó 0) ---
        if (my_x == 0 && my_y == 0) {
            if (uart_rxempty_read() == 0) {
                char c = uart_rxtx_read();         
                uart_ev_pending_write(UART_EV_RX); 

                if (c == 'r' || c == 'R') {
                    printf("\n[0,0] Comando de REBOOT recebido! Reiniciando a CPU...\n");
                    delay(50000);        
                    ctrl_reset_write(1); 
                }
            }
        }

        // --- LÓGICA DE DISPARO (Ping-Pong) ---
        if (my_x == 0 && my_y == 0) {
            // Só dispara se a rede estiver livre (já recebeu o último pong)
            if (pronto_para_enviar == 1) {
                printf("\n<- [0,0] Disparando 0x%lx para (1,1)...\n", 0xCAFE0000 + ping_counter);
                send_packet(1, 1, 0xCAFE0000 + ping_counter);
                
                pronto_para_enviar = 0; // Bloqueia novos envios até a resposta chegar!
                ping_counter++;
            }
        }

        // --- LÓGICA DE RECEBIMENTO ---
        if (noc_rx_valid_read() == 1) {
            uint32_t dado = noc_rx_data_read();
            noc_rx_ack_write(1); 
            
            // O Nó 0 recebe a resposta e destrava o próximo envio
            if (my_x == 0 && my_y == 0) {
                printf("-> [0,0] *** RECEBEU RESPOSTA: 0x%lx ***\n", dado);
                
                pronto_para_enviar = 1; // Destrava a arma para o próximo tiro
                delay(500000); // Pausa visual só para conseguirmos ler a tela confortavelmente
            }
            
            // O Nó 3 apenas rebate de volta
            if (my_x == 1 && my_y == 1) {
                send_packet(0, 0, 0xBEEF0000 + (dado & 0xFFFF));
            }
        }
    }

    return 0;
}
