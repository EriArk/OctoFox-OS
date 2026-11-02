// SPDX-License-Identifier: GPL-3.0-or-later
// Presentation/input only. NgpCraft owns both emulated machines and their link.
#include <SDL.h>
#include <SDL_ttf.h>
#include <array>
#include <cstdint>
#include <algorithm>
namespace {
SDL_Window* window; SDL_Renderer* renderer; SDL_Texture* texture; TTF_Font* font;
SDL_GameController* pad; SDL_AudioDeviceID audio; bool focused=true;
std::array<uint32_t,160*152> rgb{};
void controller() {
    if(pad&&!SDL_GameControllerGetAttached(pad)){SDL_GameControllerClose(pad);pad=nullptr;}
    if(!pad)for(int i=0;i<SDL_NumJoysticks();++i)if(SDL_IsGameController(i)){pad=SDL_GameControllerOpen(i);break;}
}
void message(const char* text) {
    if(!text||!*text||!font)return;
    auto* surface=TTF_RenderUTF8_Blended_Wrapped(font,text,SDL_Color{255,255,255,255},700);
    if(!surface)return;
    auto* image=SDL_CreateTextureFromSurface(renderer,surface);
    int w,h;SDL_GetRendererOutputSize(renderer,&w,&h);
    SDL_Rect dst{(w-surface->w)/2,(h-surface->h)/2,surface->w,surface->h};
    SDL_Rect bg{dst.x-18,dst.y-14,dst.w+36,dst.h+28};
    SDL_SetRenderDrawColor(renderer,20,24,36,235);SDL_RenderFillRect(renderer,&bg);
    if(image){SDL_RenderCopy(renderer,image,nullptr,&dst);SDL_DestroyTexture(image);}
    SDL_FreeSurface(surface);
}
}
extern "C" {
int ngpc_frontend_open(const char* fontPath) {
    SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS,"0");
    if(SDL_Init(SDL_INIT_VIDEO|SDL_INIT_AUDIO|SDL_INIT_GAMECONTROLLER)!=0||TTF_Init()!=0)return -1;
    window=SDL_CreateWindow("TrainerOS · Neo Geo Pocket Link",SDL_WINDOWPOS_CENTERED,SDL_WINDOWPOS_CENTERED,960,912,SDL_WINDOW_FULLSCREEN_DESKTOP|SDL_WINDOW_RESIZABLE);
    if(!window)return -1;
    renderer=SDL_CreateRenderer(window,-1,SDL_RENDERER_ACCELERATED);
    if(!renderer)renderer=SDL_CreateRenderer(window,-1,SDL_RENDERER_SOFTWARE);
    if(!renderer)return -1;
    texture=SDL_CreateTexture(renderer,SDL_PIXELFORMAT_ARGB8888,SDL_TEXTUREACCESS_STREAMING,160,152);
    font=TTF_OpenFont(fontPath,24);if(!texture||!font)return -1;
    SDL_AudioSpec spec{};spec.freq=44100;spec.format=AUDIO_S16LSB;spec.channels=2;spec.samples=1024;
    audio=SDL_OpenAudioDevice(nullptr,0,&spec,nullptr,0);if(audio)SDL_PauseAudioDevice(audio,0);
    controller();return 0;
}
int ngpc_frontend_poll() {
    SDL_Event e;while(SDL_PollEvent(&e)) {
        if(e.type==SDL_QUIT)return -1;
        if(e.type==SDL_WINDOWEVENT) {
            if(e.window.event==SDL_WINDOWEVENT_CLOSE)return -1;
            if(e.window.event==SDL_WINDOWEVENT_FOCUS_LOST)focused=false;
            if(e.window.event==SDL_WINDOWEVENT_FOCUS_GAINED)focused=true;
        }
    }
    controller();if(!focused)return 0;
    const auto* keys=SDL_GetKeyboardState(nullptr);
    int result=0;
    auto held=[&](SDL_GameControllerButton b){return pad&&SDL_GameControllerGetButton(pad,b);};
    int x=pad?SDL_GameControllerGetAxis(pad,SDL_CONTROLLER_AXIS_LEFTX):0;
    int y=pad?SDL_GameControllerGetAxis(pad,SDL_CONTROLLER_AXIS_LEFTY):0;
    if(keys[SDL_SCANCODE_UP]||held(SDL_CONTROLLER_BUTTON_DPAD_UP)||y < -16000)result|=1;
    if(keys[SDL_SCANCODE_DOWN]||held(SDL_CONTROLLER_BUTTON_DPAD_DOWN)||y > 16000)result|=2;
    if(keys[SDL_SCANCODE_LEFT]||held(SDL_CONTROLLER_BUTTON_DPAD_LEFT)||x < -16000)result|=4;
    if(keys[SDL_SCANCODE_RIGHT]||held(SDL_CONTROLLER_BUTTON_DPAD_RIGHT)||x > 16000)result|=8;
    if(keys[SDL_SCANCODE_Z]||held(SDL_CONTROLLER_BUTTON_A))result|=16;
    if(keys[SDL_SCANCODE_X]||held(SDL_CONTROLLER_BUTTON_B))result|=32;
    if(keys[SDL_SCANCODE_RETURN]||held(SDL_CONTROLLER_BUTTON_START))result|=64;
    // Home and system shortcuts remain owned by the ordinary TrainerOS overlay.
    return result;
}
void ngpc_frontend_present(const uint16_t* pixels,const void* samples,int bytes,const char* text) {
    if(pixels) {
        for(size_t i=0;i<rgb.size();++i){auto c=pixels[i];rgb[i]=0xff000000|((c&15)*17<<16)|(((c>>4)&15)*17<<8)|(((c>>8)&15)*17);}
        SDL_UpdateTexture(texture,nullptr,rgb.data(),160*4);
    }
    int w,h;SDL_GetRendererOutputSize(renderer,&w,&h);float scale=std::min(w/160.f,h/152.f);
    SDL_Rect dst{int((w-160*scale)/2),int((h-152*scale)/2),int(160*scale),int(152*scale)};
    SDL_SetRenderDrawColor(renderer,0,0,0,255);SDL_RenderClear(renderer);
    SDL_RenderCopy(renderer,texture,nullptr,&dst);message(text);SDL_RenderPresent(renderer);
    if(audio&&samples&&bytes>0){if(SDL_GetQueuedAudioSize(audio)>44100*4/4)SDL_ClearQueuedAudio(audio);SDL_QueueAudio(audio,samples,bytes);}
}
void ngpc_frontend_close() {
    if(audio)SDL_CloseAudioDevice(audio);if(pad)SDL_GameControllerClose(pad);
    if(font)TTF_CloseFont(font);if(texture)SDL_DestroyTexture(texture);
    if(renderer)SDL_DestroyRenderer(renderer);if(window)SDL_DestroyWindow(window);
    TTF_Quit();SDL_Quit();
}
}
