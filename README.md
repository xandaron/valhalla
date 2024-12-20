# Valhalla Graphics Engine

Valhalla is a graphics engine designed for rendering 3D scenes with a focus on non-photorealistic rendering techniques. This project aims to serve as the renderer for a future game engine.

## Features

- Non-photorealistic rendering
- Basic 3D scene rendering
- Customizable rendering settings

## Getting Started

### Prerequisites

- Odin programming language
- A 3D model to import

### Setup

1. Clone the repository:
    ```sh
    git clone https://github.com/yourusername/valhalla.git
    cd valhalla
    ```

2. Import your 3D model into the project.

3. Edit the relevant constants in `Graphics.odin` to match your model's specifications.

4. Build and run the project:
    ```sh
    odin build . -out:valhalla
    ./valhalla
    ```

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
