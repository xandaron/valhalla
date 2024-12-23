# Valhalla Graphics Engine

Valhalla is a graphics engine designed for rendering 3D scenes with a focus on non-photorealistic rendering techniques. This project aims to serve as the renderer for a future game engine.

## Features

- Basic 3D scene rendering
- Customizable rendering settings
- Support for OBJ and FBX file formats
- Support for rigged 3D models and animations
- Support for multiple light sources
- Custom shaders
- Shadow mapping
- Real-time rendering
- Cross-platform support (Windows, Linux)
- Integration with Vulkan API

## Getting Started

### Prerequisites

- Odin programming language
  - Install Odin from [here](https://odin-lang.org/docs/install/)

### Setup

Run the following script to clone the repository, build the project and run the exe:
```sh
git clone https://github.com/xandaron/valhalla.git
cd valhalla
odin build . -out:build/build.exe
./build/build.exe
```

> **Note:** On Linux, you will need to install the GLFW library separately. You can do this using your package manager. For example, on Ubuntu, you can run:
> ```sh
> sudo apt-get install libglfw3-dev
> ```

## Demo

![Demo](demo/bunny%20lights.gif)

## Roadmap

- [X] Implement basic rendering pipeline
- [X] Implement basic lighting
- [X] Implement shadow mapping
- [ ] Add support for various non-photorealistic rendering techniques
- [ ] Optimize performance
- [ ] Integrate with future game engine

## Contributing

At this time, I am not accepting contributions from others. However, you are free to fork the repository if you would like to make your own modifications or improvements.

## License

This project is licensed under the MIT License.
