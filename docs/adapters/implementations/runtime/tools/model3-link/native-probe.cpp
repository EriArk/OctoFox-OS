// SPDX-License-Identifier: GPL-3.0-or-later
// Links the pinned upstream networking sources, not a reimplementation of them.
#include "Model3/NetBoardLink.h"
#include "OSD/Logger.h"
#include <chrono>
#include <iostream>
#include <thread>

void DebugLog(const char*, ...) {}
void InfoLog(const char*, ...) {}
Result ErrorLog(const char* fmt, ...) {
    va_list args; va_start(args, fmt); vfprintf(stderr, fmt, args); va_end(args);
    fputc('\n', stderr); return Result::FAIL;
}
int main(int argc, char** argv) {
    if (argc != 3) return 2;
    const int seat = std::stoi(argv[1]), count = std::stoi(argv[2]);
    auto server = std::make_shared<CNetServer>(19700 + seat, "TrainerOS native ring check");
    if (!server->Start()) return 3;
    CNetBoardLink link(server, "127.0.0.1", 19700 + seat % count + 1);
    std::cout << "@ready" << std::endl;
    std::string line;
    while (std::getline(std::cin, line)) {
        if (line == "connect") {
            bool connected = false;
            for (int n = 0; n < 100; ++n) {
                link.Connect();
                if (link.Connected()) { connected = true; break; }
                std::this_thread::sleep_for(std::chrono::milliseconds(50));
            }
            std::cout << (connected ? "@connected" : "@failed") << std::endl;
        } else if (line.rfind("send ", 0) == 0) {
            const size_t size = std::stoul(line.substr(5));
            std::vector<uint8_t> data(size, uint8_t(seat));
            link.Send(data.data(), data.size());
            std::cout << "@sent" << std::endl;
        } else if (line == "receive") {
            auto& data = link.Receive();
            bool valid = true;
            for (auto value : data) valid &= value == (seat + count - 2) % count + 1;
            std::cout << "@received " << data.size() << ' ' << valid << std::endl;
        } else if (line == "alive") {
            std::cout << "@alive" << std::endl;
        } else break;
    }
}
