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

	std::vector<Game::SceneObject> sceneObjects = prepareScene();
	scene = new Game::Scene(sceneObjects);

	graphicsEngine = new Graphics::Engine(width, height, window, camera);
	graphicsEngine->load_assets(scene->assetPack);

	physicsEngine = new Physics::PhysicsEngine();
	physicsEngine->init(scene->objects);

	graphicsEngine->render(scene);
}

/**
* This is a temp function
* The goal is to store the scene objects in files and load them into the program.
* 
* Then a second scene file will be used to describe what objects are required and where they 
* should be positioned.
* 
* This means in the program we can simply load the scene file and it will take care of itself.
*/
std::vector<Game::SceneObject> App::prepareScene() {
	
	Game::CameraView cameraVectors;

	cameraVectors.eye	   = { -1.0,  0.0, 0.0 };
	cameraVectors.center   = {  0.0,  0.0, 0.0 };
	cameraVectors.forwards = {  1.0,  0.0, 0.0 };
	cameraVectors.right    = {  0.0, -1.0, 0.0 };
	cameraVectors.up	   = {  0.0,  0.0, 1.0 };

	camera = new Game::Camera(cameraVectors);

	std::vector<Game::SceneObject> sceneObjects;
	Game::SceneObject sceneObject;
	PhysicsObject::BodyDescriptor bodyDescriptor;
	
	// Sphere
	sceneObject.name = "sphere";
	sceneObject.model_filenames = { "models/sphere.obj", "models/ground.mtl" };
	sceneObject.texture_filenames = { "textures/ground.jpg" };
	sceneObject.preTransforms =  glm::mat4(1);
	sceneObject.objects.clear();

	bodyDescriptor.uid = "sphere_0";
	bodyDescriptor.position = glm::f64vec3(50, -10, 0);
	bodyDescriptor.velocity = glm::f64vec3(0, 1, 0);
	bodyDescriptor.angularVelocity = glm::f64vec3(glm::radians(0.0), glm::radians(0.0), glm::radians(0.0));
	bodyDescriptor.invMass = 1.0 / 10.0; // 1 / 4.0e16
	bodyDescriptor.coefRestitution = 0.8;
	bodyDescriptor.hitboxDescriptor.type = Collision::HitboxType::SPHERE;
	bodyDescriptor.hitboxDescriptor.halfDimensions.x = 1;
	sceneObject.objects.push_back(new PhysicsObject::Body(bodyDescriptor));
	
	/*bodyDescriptor.uid = "sphere_1";
	bodyDescriptor.position = glm::f64vec3(100, 1, 0);
	bodyDescriptor.velocity = glm::f64vec3(0, 0, 0);
	bodyDescriptor.angularVelocity = glm::f64vec3(glm::radians(0.0), glm::radians(0.0), glm::radians(0.0));
	bodyDescriptor.invMass = 1 / 1;
	bodyDescriptor.coefRestitution = 0.8;
	bodyDescriptor.hitboxDescriptor.type = Collision::HitboxType::SPHERE;
	bodyDescriptor.hitboxDescriptor.halfDimensions.x = 1;
	sceneObject.objects.push_back(new PhysicsObject::Body(bodyDescriptor));*/

	sceneObjects.push_back(sceneObject);

	// Cube
	sceneObject.name = "cube";
	sceneObject.model_filenames = { "models/cube.obj", "models/ground.mtl" };
	sceneObject.texture_filenames = { "textures/ground.jpg" };
	//sceneObject.preTransforms = glm::mat4(1);
	sceneObject.preTransforms = glm::mat4(
		1, 0, 0,  0,
		0, 1, 0,  0,
		0, 0, 20,  0,
		0, 0, 0,  1);
	sceneObject.objects.clear();

	//bodyDescriptor.uid = "cube_0";
	//bodyDescriptor.position = glm::f64vec3(50, 0, 0);
	//bodyDescriptor.velocity = glm::f64vec3(0, 0, 0);
	//bodyDescriptor.angularVelocity = glm::f64vec3(glm::radians(0.0), glm::radians(0.0), glm::radians(0.0));
	//bodyDescriptor.invMass = 1 / 1; // 1 / 4.0e16
	//bodyDescriptor.coefRestitution = 0.8;
	//bodyDescriptor.hitboxDescriptor.type = Collision::HitboxType::AABB;
	//bodyDescriptor.hitboxDescriptor.halfDimensions = glm::f64vec3(1, 1, 10);
	//sceneObject.objects.push_back(new PhysicsObject::Body(bodyDescriptor));

	bodyDescriptor.uid = "cube_1";
	bodyDescriptor.position = glm::f64vec3(50, 10, 0);
	bodyDescriptor.velocity = glm::f64vec3(0, 0, 0);
	bodyDescriptor.angularVelocity = glm::f64vec3(glm::radians(0.0), glm::radians(0.0), glm::radians(0.0));
	bodyDescriptor.invMass = 1.0 / 10.0;
	bodyDescriptor.coefRestitution = 0.8;
	bodyDescriptor.hitboxDescriptor.type = Collision::HitboxType::AABB;
	bodyDescriptor.hitboxDescriptor.halfDimensions = glm::f64vec3(1, 1, 20);
	sceneObject.objects.push_back(new PhysicsObject::Body(bodyDescriptor));

	sceneObjects.push_back(sceneObject);

	return sceneObjects;
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