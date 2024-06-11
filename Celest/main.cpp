#include "app.h"

App* myApp;

int main() {

	int type = Debug::MESSAGE | Debug::DEBUG | Debug::MINOR_ERROR | Debug::MAJOR_ERROR;
	Debug::Logger::setup(type);

	int returnCode = 0;

	try {
		myApp = new App(640, 480);
		myApp->Run();
	}
	catch (std::exception err) {
		Debug::Logger::log(Debug::MAJOR_ERROR, err.what());
		returnCode = -1;
	}

	delete myApp;
	return returnCode;
}