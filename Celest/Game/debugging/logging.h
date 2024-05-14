#pragma once
#include <string>
#include <iostream>
#include <fstream>
#include <iomanip>
#include <ctime>
#include <chrono>
#include <unordered_map>

namespace Logging {

	enum logType {
		MESSAGE,
		LOW_ERROR,
		HIGH_ERROR
	};

	struct Log {
		logType type = logType::MESSAGE;
		std::string message = "";
	};

	class Logger {
	public:
		
		static void createLogger(std::string dir, unsigned int control) {
			fileDir = dir;
			fileName = "debug.txt";
			controlBits = control;

			file.open(fileDir + fileName, std::fstream::out);
			if (file.is_open()) {
				file << "\nNew launch\n" << std::endl;
				file.close();
			}
			else {
				std::cout << "Unable to open file" << std::endl;
			}
		}

		static void log(Log log) {

			std::string str = "[" + getLogTypeString(log.type) + "]" + " " + log.message;

			if (controlBits & 1) {
				std::cout << str << std::endl;
			}
			if (controlBits & 2) {
				file.open(fileDir + fileName, std::fstream::out);
				if (file.is_open()) {
					file << str << std::endl;
					file.close();
				}
				else {
					std::cout << "Unable to open file" << std::endl;
				}
			}
		}

		static std::string getLogTypeString(logType t) {
			logType::MESSAGE;
			logType::LOW_ERROR;
			logType::HIGH_ERROR;

			std::string type;

			if (t == logType::MESSAGE) {
				type = "Message";
			}
			else if (t == logType::LOW_ERROR) {
				type = "Error-Benign";
			}
			else if (t == logType::HIGH_ERROR) {
				type = "Error-Severe";
			}
			else {
				type = "Unknown";
			}

			return type;
		}

		static void print_list(std::vector<std::string> items) {
			for (std::string item : items) {
				std::cout << "\t\t" << item << std::endl;
			}
		}

		static void createTimedOpperation(std::string id) {
			timers[id] = std::chrono::high_resolution_clock::now();
		}

		static void finishTimer(std::string id) {
			auto duration = std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::high_resolution_clock::now() - timers[id]);
			Log l;
			l.message = std::format("Timed opperation {} took {} microseconds to complete.", id, duration.count());
			log(l);
		}

	private:
		static std::string fileName;
		static std::string fileDir;
		static std::fstream file;
		static std::unordered_map<std::string, std::chrono::steady_clock::time_point> timers;
		static unsigned int controlBits;
	};
}