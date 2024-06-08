#pragma once
#include "../../cfg.h"

namespace util {
	class FileLoader {

	public:
		FileLoader(std::string filedir, std::string filename) {
			this->filedir = filedir;
			this->filepath = filedir + filename;
		}

		virtual bool load() = 0;

	protected:
		std::string filedir;
		std::string filepath;
	};
}