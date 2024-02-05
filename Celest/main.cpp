#include "app.h"

App* myApp;

int main() {

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