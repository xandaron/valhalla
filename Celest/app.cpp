#include "app.h"
#include "Graphics/control/logging.h"

/**
* Construct a new App.
*
* @param width	the width of the window
* @param height the height of the window
* @param debug	whether to run the app with vulkan validation layers and extra print statements
*/
App::App(int width, int height, bool debug) {

	vkLogging::Logger::get_logger()->set_debug_mode(debug);

	if (!build_glfw_window(width, height, debug)) { 
		throw "Failed to build GLFW window.";
	}

	//std::vector<Game::SceneObject> sceneObjects = prepareScene();
	scene = new Game::Scene("assets/scenes/double_orbit.scene");
	camera = scene->GetCamera();

	graphicsEngine = new Graphics::Engine(width, height, window, camera);
	graphicsEngine->load_assets(scene->GetAssetPack());

	physicsEngine = new Physics::PhysicsEngine();
	physicsEngine->init(scene->GetPhysicsObjects());

	graphicsEngine->render(scene);
}

/**
* Build the App's window (using glfw)
*
* @param width		the width of the window
* @param height		the height of the window
* @param debugMode	whether to make extra print statements
*/
bool App::build_glfw_window(int width, int height, bool debug) {

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

	if (window = glfwCreateWindow(width, height, "Not KSP", nullptr, nullptr)) {
		message << "Successfully made a glfw window called \"Not KSP\", width: " << width << ", height: " << height;
		vkLogging::Logger::get_logger()->print(message.str());
	}
	else {
		vkLogging::Logger::get_logger()->print("GLFW window creation failed");
		return false;
	}

	glfwSetKeyCallback(window, key_callback);
	glfwSetMouseButtonCallback(window, mouse_button_callback);
	glfwSetScrollCallback(window, scroll_callback);
	return true;
}

void App::updateTitle(std::string title) {

	glfwSetWindowTitle(window, title.c_str());
}

double App::calculateDeltaTime() {

	currentTime = glfwGetTime();
	double delta = currentTime - lastTime;
	lastTime = currentTime;
	return delta;
}

/**
* Calculates the App's framerate and updates the window title
*/
void App::calculateFrameRate() {

	double delta = glfwGetTime() - fpsTimer;
	if (delta >= 1) {
		fpsTimer = glfwGetTime();
		int framerate{ std::max(1, int(numFrames / delta)) };
		updateTitle(std::to_string(framerate));
		numFrames = -1;
		frameTime = float(1000.0 / framerate);
	}
	++numFrames;
}

void App::cameraUpdate(double delta) {

	if (middleMouse) {
		double xpos, ypos;
		glfwGetCursorPos(window, &xpos, &ypos);
		cameraRotationVector.y = mousePos.y - ypos;
		cameraRotationVector.z = mousePos.x - xpos;
		mousePos = { xpos, ypos };
	}

	camera->updateCamera(cameraMovementVector * 0.1, cameraRotationVector, delta);

	cameraRotationVector.y = 0;
	cameraRotationVector.z = 0;
}

/**
* Start the App's main loop
*/
void App::run() {

	while (!glfwWindowShouldClose(window)) {
		glfwPollEvents();
		double delta = calculateDeltaTime() * timeWarp;
		calculateFrameRate();
		cameraUpdate(delta);
		physicsEngine->update(delta);
		graphicsEngine->render(scene);
	}
}

/**
* App destructor.
*/
App::~App() {

	glfwDestroyWindow(window);
	glfwTerminate();

	delete graphicsEngine;
	delete physicsEngine;
	delete scene;
}