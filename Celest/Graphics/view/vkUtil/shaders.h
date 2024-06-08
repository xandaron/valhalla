#pragma once
#include "../../../cfg.h"
#include "../../control/logging.h"

namespace vkUtil {

	/**
	* Read a binary file.
	*
	* @param filename A string representing the path to the file.
	*
	* @returns The contents as a vector of raw binary characters.
	* 
	* @throws std::invalid_argument The file couldn't be opened.
	*/
	std::vector<char> readFile(std::string filename);

	/**
	* Make a shader module.
	*
	* @param filename A string holding the filepath to the spir-v file.
	* @param device   The logical device.
	*
	* @return The created shader module.
	* 
	* @throws std::invalid_argument The file couldn't be opened.
	* @throws std::runtime_error	Couldn't create the shader modual.
	*/
	vk::ShaderModule createModule(std::string filename, vk::Device device);
}