# Jord

> _"Jörð (Old Norse: Jǫrð, lit.'earth'), also named Fjorgyn or Hlodyn, is the personification of earth and a goddess in Norse mythology. She is the mother of the thunder god Thor and a partner of Odin."_ - [Wikipedia](https://en.wikipedia.org/wiki/J%C3%B6r%C3%B0)

Graphics Rendering Sandbox in [Odin](https://odin-lang.org/) using [SDL3](https://wiki.libsdl.org/SDL3/FrontPage)

!NOTE: Only tested on Pop!_OS 22.04

## Requires:
- [SDL3](https://github.com/libsdl-org/SDL)
- [SDL3_image](https://github.com/libsdl-org/SDL_image)
- [SDL3_ttf](https://github.com/libsdl-org/SDL_ttf)

## Installing SDL3 on Linux:
Clone each of the repos and from inside them, run this:
```
mkdir build
cd build
cmake .. -B .
make
sudo make install
```

Ensure you set LD_LIBRARY_PATH: `export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH`

![capture](docs/capture.mp4)
