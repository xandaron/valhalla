#include "app.h"
#include "Graphics/control/logging.h"

/**
* @param width	the width of the window
* @param height the height of the window
* @param debug	whether to run the app with vulkan validation layers and extra print statements
*/
App::App(int width, int height, bool debug) {

	playerController = new Controller::PlayerController();

	fpsTimer = glfwGetTime();

	mousePos = glm::vec2(0);
	mouseSensitivity = 0.5f;
	movementSpeed = 0.05f;
	mouseLock = false;
	
	vkLogging::Logger::get_logger()->set_debug_mode(debug);

	if (!Build_GLFW_Window(width, height, debug)) {
		throw "Failed to build GLFW window.";
	}

	//std::vector<Game::SceneObject> sceneObjects = prepareScene();
	scene = new Game::Scene("assets/scenes/monke.scene");
	Game::Camera* camera = scene->getCamera();

	if (camera->getMode() == Game::Camera::CameraMode::FOLLOW) {
		camera->getTarget()->setController(playerController);
	}
	else {
		camera->setController(playerController);
	}

	graphicsEngine = new Graphics::Engine(width, height, window, camera);
	graphicsEngine->loadAssets(scene->getAssetPack());

	physicsEngine = new Physics::Engine();

	graphicsEngine->render(scene);
}

/**
* Build the App's window (using glfw)
*
* @param width		the width of the window
* @param height		the height of the window
* @param debugMode	whether to make extra print statements
*/
bool App::Build_GLFW_Window(int width, int height, bool debug) {

	std::stringstream message;

	if (debug) {
		glfwSetErrorCallback(error_callback);
	}

	if (!glfwInit()) {
		vkLogging::Logger::get_logger()->print("GLFW window init failed");
		return false;
	}

	glfwWindowHint(GLFW_CLIENT_API, GLFW_NO_API);
	glfwWindowHint(GLFW_RESIZABLE, GLFW_TRUE);

	if (window = glfwCreateWindow(width, height, "Celest", nullptr, nullptr)) {
		message << "Successfully made a glfw window called \"Celest\", width: " << width << ", height: " << height;
		vkLogging::Logger::get_logger()->print(message.str());
	}
	else {
		vkLogging::Logger::get_logger()->print("GLFW window creation failed");
		return false;
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

	delete graphicsEngine;
	delete physicsEngine;
	delete scene;

	delete playerController;
}