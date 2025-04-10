#include <stdio.h>
#include <stdlib.h>

// vertex structure representing (node, channel) pair
typedef struct {
    unsigned int node;    // 4 bytes - node index
    unsigned short ch;    // 2 bytes - channel index
} vertex;

int main(int argc, char *argv[]) {
    printf("Hello, World!\n");
    return 0;
} 