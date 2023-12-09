#pragma once
#include "GraphicsEngine/view/engine.h"
#include "PhysicsEngine/physics_engine.h"

static class App {

public:
	Physics::PhysicsEngine* physicsEngine;

	Graphics::Engine* graphicsEngine;
	vkUtil::Camera* camera;
	GLFWwindow* window;
	Scene* scene;

	double lastTime, currentTime;
	double fpsTimer;
	int numFrames;
	float frameTime;

	float cameraDX = 0;
	float cameraDY = 0;

	bool build_glfw_window(int width, int height, bool debug);

	void updateTitle(std::string title);

	double calculateDeltaTime();

	void calculateFrameRate();

	void increaseCameraSpeed();
	void decreaseCameraSpeed();

	App(int width, int height, bool debug);
	~App();
	void run();
};

static void error_callback(int error, const char* description)
{
	std::cout << "Error: %s\n" << description << std::endl;
}

static void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods)
{
	extern App* myApp;

	

	if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS) {
		glfwSetWindowShouldClose(window, GLFW_TRUE);
	}

	if (key == GLFW_KEY_LEFT_SHIFT) {
		myApp->increaseCameraSpeed();
	}

	if (key == GLFW_KEY_LEFT_CONTROL) {
		myApp->decreaseCameraSpeed();
	}

	if (key == GLFW_KEY_W) {
		if (action == GLFW_PRESS) {
			myApp->cameraDX++;
		}
		else if (action == GLFW_RELEASE) {
			myApp->cameraDX--;
		}
	}

	if (key == GLFW_KEY_S) {
		if (action == GLFW_PRESS) {
			myApp->cameraDX--;
		}
		else if (action == GLFW_RELEASE) {
			myApp->cameraDX++;
		}
	}

	if (key == GLFW_KEY_A) {
		if (action == GLFW_PRESS) {
			myApp->cameraDY--;
		}
		else if (action == GLFW_RELEASE) {
			myApp->cameraDY++;
		}
	}

	if (key == GLFW_KEY_D) {
		if (action == GLFW_PRESS) {
			myApp->cameraDY++;
		}
		else if (action == GLFW_RELEASE) {
			myApp->cameraDY--;
		}
	}
}