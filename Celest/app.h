#pragma once
#include "cfg.h"
#include "Graphics/view/engine.h"
#include "Physics/physics_engine.h"
#include "Game/camera.h"
#include "Game/scene.h"

class App {

public:


	GLFWwindow* window;

	Physics::PhysicsEngine* physicsEngine;
	Graphics::Engine* graphicsEngine;
	Game::Camera* camera;
	Game::Scene* scene;

	double lastTime, currentTime;
	double fpsTimer = glfwGetTime();
	int numFrames;
	float frameTime;

	double timeWarp = 5;

	glm::f64vec3 cameraMovementVector = { 0, 0, 0 };
	glm::f64vec3 cameraRotationVector = { 0, 0, 0 };
	glm::f64vec2 mousePos = { 0, 0 };
	bool middleMouse = false;

	
	App(int width, int height, bool debug);

	bool build_glfw_window(int width, int height, bool debug);

	void updateTitle(std::string title);

	double calculateDeltaTime();

	void calculateFrameRate();

	void cameraUpdate(double delta);

	void run();

	~App();
};

extern App* myApp;

static void error_callback(int error, const char* description)
{
	std::cout << "Error: %s\n" << description << std::endl;
}

static void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods)
{
	if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS) {
		glfwSetWindowShouldClose(window, GLFW_TRUE);
	}
	
	if (key == GLFW_KEY_E) {
		if (action == GLFW_PRESS) {
			myApp->cameraRotationVector.x++;
		}
		else if (action == GLFW_RELEASE) {
			myApp->cameraRotationVector.x--;
		}
	}

	if (key == GLFW_KEY_Q) {
		if (action == GLFW_PRESS) {
			myApp->cameraRotationVector.x--;
		}
		else if (action == GLFW_RELEASE) {
			myApp->cameraRotationVector.x++;
		}
	}

	if (key == GLFW_KEY_W) {
		if (action == GLFW_PRESS) {
			myApp->cameraMovementVector.x++;
		}
		else if (action == GLFW_RELEASE) {
			myApp->cameraMovementVector.x--;
		}
	}

	if (key == GLFW_KEY_S) {
		if (action == GLFW_PRESS) {
			myApp->cameraMovementVector.x--;
		}
		else if (action == GLFW_RELEASE) {
			myApp->cameraMovementVector.x++;
		}
	}

	if (key == GLFW_KEY_A) {
		if (action == GLFW_PRESS) {
			myApp->cameraMovementVector.y--;
		}
		else if (action == GLFW_RELEASE) {
			myApp->cameraMovementVector.y++;
		}
	}

	if (key == GLFW_KEY_D) {
		if (action == GLFW_PRESS) {
			myApp->cameraMovementVector.y++;
		}
		else if (action == GLFW_RELEASE) {
			myApp->cameraMovementVector.y--;
		}
	}
	
	if (key == GLFW_KEY_SPACE) {
		if (action == GLFW_PRESS) {
			myApp->cameraMovementVector.z++;
		}
		else if (action == GLFW_RELEASE) {
			myApp->cameraMovementVector.z--;
		}
	}

	if (key == GLFW_KEY_LEFT_SHIFT) {
		if (action == GLFW_PRESS) {
			myApp->cameraMovementVector.z--;
		}
		else if (action == GLFW_RELEASE) {
			myApp->cameraMovementVector.z++;
		}
	}

	if (key == GLFW_KEY_R && action == GLFW_PRESS) {
		myApp->camera->reset();
	}
}

static void mouse_button_callback(GLFWwindow* window, int button, int action, int mods)
{
	if (button == GLFW_MOUSE_BUTTON_MIDDLE) {
		if (action == GLFW_PRESS) {
			myApp->middleMouse = true; 
			glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
		}
		else if (action == GLFW_RELEASE) {
			myApp->middleMouse = false;
			glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
		}
	}
}

static void scroll_callback(GLFWwindow* window, double xoffset, double yoffset)
{
	if (!myApp->middleMouse) {

	}
}