#include "app.h"
//#include "Game/console/logging.h"

App* myApp;

int main() {

	//Logging::Logger::createLogger("logs/", 0);
	try {
		myApp = new App(640, 480, true);
	}
	catch (std::string e) {
		std::cerr << e << std::endl;
		return -1;
	}

	myApp->run();
	delete myApp;

	return 0;
}