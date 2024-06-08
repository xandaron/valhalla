#include "app.h"

App* myApp;

int main() {

	int type = Debug::MESSAGE | Debug::DEBUG | Debug::MINOR_ERROR | Debug::MAJOR_ERROR;
	Debug::Logger::setup(type);

	try {
		myApp = new App(640, 480, true);
		myApp->Run();
	}
	catch (std::exception err) {
		Debug::Logger::log(Debug::MAJOR_ERROR, err.what());
		std::cerr << err.what() << std::endl;
		return -1;
	}

	delete myApp;
	return 0;
}