#import "GeneratedPluginRegistrant.h"
#import <os/proc.h>
#include <stdint.h>
// Per-process memory headroom, not total device RAM. iOS 17 deployment target.
static inline uint64_t alo_available_process_memory(void) {
  return (uint64_t)os_proc_available_memory();
}
