#pragma once
#include "../../cfg.h"

namespace Fileloader {
	class File_Loader {

	public:
		File_Loader(std::string filedir, std::string filename) {
			this->filedir = filedir;
			this->filepath = filedir + filename;
		}

		virtual bool load() = 0;

	protected:
		std::string filedir;
		std::string filepath;
	};
}