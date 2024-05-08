#pragma once
#include "cfg.h"
#include "Graphics/view/graphics_engine.h"
#include "Physics/physics_engine.h"
#include "Game/camera.h"
#include "Game/scene.h"
#include "Game/player_controller.h"

class App {
public:
	GLFWwindow* window;

	Physics::Engine* physicsEngine;
	Graphics::Engine* graphicsEngine;
	Game::Scene* scene;

	Controller::PlayerController* playerController = new Controller::PlayerController();

	double lastTime, currentTime;
	double fpsTimer = glfwGetTime();
	int numFrames;
	float frameTime;

	double timeWarp = 1;

	glm::vec2 mousePos = glm::vec2(0);
	float mouseSensitivity = 0.5;
	float movementSpeed = 0.3;
	bool mouseLock = false;

	
	App(int width, int height, bool debug);

	bool build_glfw_window(int width, int height, bool debug);

	void updateTitle(std::string title);

	double calculateDeltaTime();

	void calculateFrameRate();

	void run();

	void nextCamera();

	void resetCamera();

	~App();
};

extern App* myApp;

static void error_callback(int error, const char* description) {
	std::cout << "Error: %s\n" << description << std::endl;
}

static void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods) {
	if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS) {
		glfwSetWindowShouldClose(window, GLFW_TRUE);
	}
	
	if (key == GLFW_KEY_L) {
		if (action == GLFW_PRESS) {
			myApp->nextCamera();
		}
	}

	if (key == GLFW_KEY_E) {
		if (action == GLFW_PRESS) {
			myApp->playerController->rotationVector.x++;
		}
		else if (action == GLFW_RELEASE) {
			myApp->playerController->rotationVector.x--;
		}
	}

	if (key == GLFW_KEY_Q) {
		if (action == GLFW_PRESS) {
			myApp->playerController->rotationVector.x--;
		}
		else if (action == GLFW_RELEASE) {
			myApp->playerController->rotationVector.x++;
		}
	}

	if (key == GLFW_KEY_W) {
		if (action == GLFW_PRESS) {
			myApp->playerController->movementVector.x++;
		}
		else if (action == GLFW_RELEASE) {
			myApp->playerController->movementVector.x--;
		}
	}

	if (key == GLFW_KEY_S) {
		if (action == GLFW_PRESS) {
			myApp->playerController->movementVector.x--;
		}
		else if (action == GLFW_RELEASE) {
			myApp->playerController->movementVector.x++;
		}
	}

	if (key == GLFW_KEY_A) {
		if (action == GLFW_PRESS) {
			myApp->playerController->movementVector.y++;
		}
		else if (action == GLFW_RELEASE) {
			myApp->playerController->movementVector.y--;
		}
	}

	if (key == GLFW_KEY_D) {
		if (action == GLFW_PRESS) {
			myApp->playerController->movementVector.y--;
		}
		else if (action == GLFW_RELEASE) {
			myApp->playerController->movementVector.y++;
		}
	}
	
	if (key == GLFW_KEY_SPACE) {
		if (action == GLFW_PRESS) {
			myApp->playerController->movementVector.z++;
		}
		else if (action == GLFW_RELEASE) {
			myApp->playerController->movementVector.z--;
		}
	}

	if (key == GLFW_KEY_LEFT_SHIFT) {
		if (action == GLFW_PRESS) {
			myApp->playerController->movementVector.z--;
		}
		else if (action == GLFW_RELEASE) {
			myApp->playerController->movementVector.z++;
		}
	}

	if (key == GLFW_KEY_R && action == GLFW_PRESS) {
		myApp->resetCamera();
	}
}

static void mouse_button_callback(GLFWwindow* window, int button, int action, int mods) {
	if (button == GLFW_MOUSE_BUTTON_MIDDLE) {
		if (action == GLFW_PRESS) {
			if (myApp->mouseLock) {
				myApp->mouseLock = false;
				glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_NORMAL);
			}
			else {
				myApp->mouseLock = true;
				glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
			}
		}
	}
}

static void cursor_position_callback(GLFWwindow* window, double xpos, double ypos) {
	if (myApp->mouseLock) {
		glm::vec2 mouseMovement = glm::vec2(xpos, ypos) - myApp->mousePos;
		myApp->playerController->rotationVector.y = mouseMovement[1];
		myApp->playerController->rotationVector.z = -mouseMovement[0];
		myApp->mousePos = glm::vec2(xpos, ypos);
	}
}

static void scroll_callback(GLFWwindow* window, double xoffset, double yoffset)
{
}