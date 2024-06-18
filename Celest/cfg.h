#pragma once
#define GLM_FORCE_SWIZZLE
#define GLM_FORCE_DEPTH_ZERO_TO_ONE
#include <glm/glm.hpp>
#include <glm/gtc/matrix_transform.hpp>

#include <iostream>
#include <fstream>

#include <vector>
#include <set>
#include <unordered_map>

#include <string>
#include <sstream>
#include <format>

#include "debug/logger.h"

// split string on specified character
static std::vector<std::string> split(std::string line, std::string delimiter) {

	std::vector<std::string> split_line;

	size_t pos = 0;
	std::string token;
	while ((pos = line.find(delimiter)) != std::string::npos) {
		token = line.substr(0, pos);
		split_line.push_back(token);
		line.erase(0, pos + delimiter.length());
	}
	split_line.push_back(line);

	return split_line;
}

// trim from start (in place)
inline void ltrim(std::string& s) {
	s.erase(
		s.begin(),
		std::find_if(
			s.begin(),
			s.end(),
			[](unsigned char ch) {
				return !std::isspace(ch);
			}
		)
	);
}

// trim from end (in place)
inline void rtrim(std::string& s) {
	s.erase(
		std::find_if(
			s.rbegin(),
			s.rend(),
			[](unsigned char ch) {
				return !std::isspace(ch);
			}
		).base(),
		s.end()
	);
}

// trim from both ends (in place)
inline void trim(std::string& s) {
	rtrim(s);
	ltrim(s);
}