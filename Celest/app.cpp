#include "app.h"
#include "Graphics/control/logging.h"

/**
* @param width	The width of the window.
* @param height The height of the window.
*/
App::App(int width, int height) {
	playerController = new Controller::PlayerController();

	fpsTimer = glfwGetTime();
	mousePos = glm::vec2(0);
	mouseSensitivity = 0.5f;
	movementSpeed = 0.05f;
	mouseLock = false;
	
	Build_GLFW_Window(width, height);

	scene = new Game::Scene("assets/scenes/monke.scene");
	Game::Camera* camera = scene->getCamera();

	if (camera->getMode() == Game::Camera::CameraMode::FOLLOW) {
		camera->getTarget()->setController(playerController);
	}
	else {
		camera->setController(playerController);
	}

	physicsEngine = new Physics::Engine();

	graphicsEngine = new Graphics::Engine(width, height, window, camera);
	graphicsEngine->loadAssets(scene->getAssetPack());
}

/**
* Build the App's window (using glfw)
*
* @param width		the width of the window
* @param height		the height of the window
* @param debugMode	whether to make extra print statements
*/
bool App::Build_GLFW_Window(int width, int height) {

	std::stringstream message;

	glfwSetErrorCallback(error_callback);

	if (!glfwInit()) {
		throw std::runtime_error("GLFW window init failed!");
	}

	glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
	glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE);

	if (window = glfwCreateWindow(width, height, "Celest", nullptr, nullptr)) {
		Debug::Logger::log(Debug::MESSAGE, 
			std::format("Successfully made a glfw window called \"Celest\", width: {}, height: {}", width, height)
		);
	}
	else {
		throw std::runtime_error("Failed to create GLFW window!");
	}

	glfwSetKeyCallback(window, key_callback);
	glfwSetMouseButtonCallback(window, mouse_button_callback);
	glfwSetScrollCallback(window, scroll_callback);
	glfwSetCursorPosCallback(window, cursor_position_callback);
	return true;
}

void App::UpdateTitle(std::string title) {
	glfwSetWindowTitle(window, title.c_str());
}

double App::CalculateDeltaTime() {
	currentTime = glfwGetTime();
	double delta = currentTime - lastTime;
	lastTime = currentTime;
	return delta;
}

/**
* Calculates the App's framerate and updates the window title
* 
* @param delta Time since last frame.
*/
void App::CalculateFrameRate(double delta) {
	double framerate = 1.0 / delta;
	UpdateTitle(std::to_string(framerate));
}

/**
* Start the App's main loop
*/
void App::Run() {
	while (!glfwWindowShouldClose(window)) {
		glfwPollEvents();
		double delta = CalculateDeltaTime();
		CalculateFrameRate(delta);
		scene->update(delta);
		playerController->rotationVector.y = 0;
		playerController->rotationVector.z = 0;
		physicsEngine->update(delta);
		graphicsEngine->render(scene);
	}
}

void App::NextCamera() {
	scene->cycleCamera(playerController);
}

void App::ResetCamera() {
	scene->getCamera()->reset();
}

App::~App() {
	glfwDestroyWindow(window);
	glfwTerminate();

	delete playerController;
	delete physicsEngine;
	delete graphicsEngine;
	delete scene;
}