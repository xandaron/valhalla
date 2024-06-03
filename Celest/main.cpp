#include "app.h"

App* myApp;

int main() {

	int type = Debug::MESSAGE | Debug::DEBUG | Debug::MINOR_ERROR | Debug::MAJOR_ERROR;
	Debug::Logger::setup(type);

	try {
		myApp = new App(640, 480, true);
	}
	catch (std::string e) {
		std::cerr << e << std::endl;
		return -1;
	}

	myApp->Run();

	delete myApp;

	return 0;
}