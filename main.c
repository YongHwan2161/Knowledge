#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Global variables for graph management
unsigned char** graph = NULL;
unsigned int graph_size = 0;
unsigned int max_graph_size = 10;
unsigned int last_node_index = 0;  // Tracks the last created node index

// Function to calculate the next power of 2
static inline unsigned int next_power_of_2(unsigned int n) {
    // if (n == 0) return 1; // should not happen
    n--;
    n |= n >> 1;
    n |= n >> 2;
    n |= n >> 4;
    n |= n >> 8;
    n |= n >> 16;
    return n + 1;
}

// Function to allocate memory in power-of-2 size
unsigned char* allocate_power_of_2(unsigned int requested_size) {
    if (requested_size == 0) return NULL;
    
    // Calculate the next power of 2 that is >= requested_size
    unsigned int power_of_2_size = next_power_of_2(requested_size);
    
    // Allocate memory
    unsigned char* memory = (unsigned char*)malloc(power_of_2_size);
    if (memory == NULL) {
        return NULL;
    }
    return memory;
}

// Function to create a new node
void create_node() {
    // Check if graph needs to be resized
    if (graph_size >= max_graph_size) {
        max_graph_size *= 2;
        graph = (unsigned char**)realloc(graph, max_graph_size * sizeof(unsigned char*));
        if (graph == NULL) {
            printf("Graph resize failed\n");
            return;
        }
    }

    // Allocate memory for new node
    unsigned char* node = allocate_power_of_2(16);
    if (node == NULL) {
        printf("Memory allocation failed\n");
        return;
    }

    // Initialize node data
    *((unsigned int*)node) = last_node_index;      // node index
    *((unsigned int*)(node + 4)) = 16;            // allocated size
    *((unsigned int*)(node + 8)) = 14;            // used size
    *((unsigned short*)(node + 12)) = 0;          // channel count

    // Add node to graph
    graph[graph_size] = node;
    graph_size++;
    last_node_index++;
}

// Function to find a node by index
unsigned char* find_node(unsigned int index) {
    for (unsigned int i = 0; i < graph_size; i++) {
        if (*((unsigned int*)graph[i]) == index) {
            return graph[i];
        }
    }
    return NULL;  // Node not found in memory
}

int main(int argc, char *argv[]) {
    // Initialize graph
    graph = (unsigned char**)malloc(max_graph_size * sizeof(unsigned char*));
    if (graph == NULL) {
        printf("Graph initialization failed\n");
        return 1;
    }

    // Create some nodes
    create_node();
    create_node();

    // Example of finding a node
    unsigned char* node0 = find_node(0);
    if (node0 != NULL) {
        printf("Found node 0\n");
    }

    // Clean up
    for (unsigned int i = 0; i < graph_size; i++) {
        free(graph[i]);
    }
    free(graph);
    
    return 0;
} 