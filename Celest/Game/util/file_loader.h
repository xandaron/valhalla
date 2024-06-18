#pragma once
#include "../../cfg.h"

namespace util {
	class FileLoader {

	public:
		FileLoader(std::string filepath) {
			this->filepath = filepath;
		}

		virtual bool load() = 0;

	protected:
		std::string filepath;
	};
}