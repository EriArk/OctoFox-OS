/* SPDX-License-Identifier: GPL-3.0-or-later
 * Headless ABI/loading check only. Does not init a core or load game/save data.
 */
#include <dlfcn.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>
struct system_info { const char *name, *version, *extensions; bool fullpath, block_extract; };
static void json_string(const char *s) {
    if (!s) { fputs("null", stdout); return; }
    putchar('"');
    for (size_t i = 0; s[i] && i < 4096; ++i) {
        unsigned char c = s[i];
        if (c == '"' || c == '\\') { putchar('\\'); putchar(c); }
        else if (c < 32) printf("\\u%04x", c);
        else putchar(c);
    }
    putchar('"');
}
int main(int argc, char **argv) {
    if (argc != 2) return 2;
    void *core = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!core) { fprintf(stderr, "%s\n", dlerror()); return 3; }
    const char *symbols[] = {"retro_init", "retro_deinit", "retro_api_version", "retro_get_system_info",
        "retro_get_system_av_info", "retro_set_environment", "retro_set_video_refresh",
        "retro_set_audio_sample", "retro_set_audio_sample_batch", "retro_set_input_poll",
        "retro_set_input_state", "retro_set_controller_port_device", "retro_reset", "retro_run",
        "retro_serialize_size", "retro_serialize", "retro_unserialize", "retro_cheat_reset",
        "retro_cheat_set", "retro_load_game", "retro_load_game_special", "retro_unload_game",
        "retro_get_region", "retro_get_memory_data", "retro_get_memory_size"};
    for (size_t i = 0; i < sizeof(symbols) / sizeof(*symbols); ++i)
        if (!dlsym(core, symbols[i])) { fprintf(stderr, "Missing ABI symbol: %s\n", symbols[i]); return 4; }
    unsigned (*api)(void) = dlsym(core, "retro_api_version");
    void (*info)(struct system_info *) = dlsym(core, "retro_get_system_info");
    if (api() != 1) return 5;
    struct system_info value = {0}; info(&value);
    fputs("{\"api\":1,\"name\":", stdout); json_string(value.name);
    fputs(",\"version\":", stdout); json_string(value.version);
    fputs(",\"extensions\":", stdout); json_string(value.extensions);
    printf(",\"fullpath\":%s,\"blockExtract\":%s}\n", value.fullpath ? "true" : "false", value.block_extract ? "true" : "false");
    dlclose(core);
    return 0;
}
