#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <time.h>

#define NETWORK_BASE 0x20000000  // Base dos CSRs

#define TX_DATA   (*(volatile unsigned int *)(NETWORK_BASE + 0x00))
#define RX_DATA   (*(volatile unsigned int *)(NETWORK_BASE + 0x04))
#define STATUS    (*(volatile unsigned int *)(NETWORK_BASE + 0x08))

#define TX_FULL   (1 << 0)
#define RX_EMPTY  (1 << 1)

void send_packet(unsigned char dest, const unsigned char *data, int len) {
    while (STATUS & TX_FULL) ;
    TX_DATA = dest;
    for (int i = 0; i < len; i++) {
        while (STATUS & TX_FULL) ;
        TX_DATA = data[i];
    }
}

int receive_byte(void) {
    if (STATUS & RX_EMPTY)
        return -1;
    return RX_DATA & 0xFF;
}

int main() {
    int node_id = NODE_ID;
    srand(time(NULL) + node_id);
    printf("Nó %d iniciado.\n", node_id);

    unsigned char packet[] = {'H', 'i', '!'};
    while (1) {
        int dest;
        do {
            dest = rand() % 4;
        } while (dest == node_id);

        send_packet(dest, packet, sizeof(packet));
        printf("Nó %d enviou para %d\n", node_id, dest);

        int byte = receive_byte();
        if (byte != -1) {
            printf("Nó %d recebeu: %c\n", node_id, byte);
        }
        sleep(1);
    }
    return 0;
}
