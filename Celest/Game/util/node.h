#pragma once
#include "../../cfg.h"
#include <variant>

namespace util {

	using propertyArray_t = std::vector<std::variant<int8_t, int32_t, int64_t, float, double>>;

	class Node {
	public:
		Node(std::string name, uint32_t endOffset, uint32_t numProperties);

		void addProperties(std::vector<std::variant<uint8_t, int16_t, int32_t, int64_t, float, double, propertyArray_t>> properties);

		void addNode(Node* node);

		uint32_t getEndOffset();

		std::string getName();

		std::vector<Node*> getChildNodes();

		std::vector<std::variant<uint8_t, int16_t, int32_t, int64_t, float, double, propertyArray_t>> getProperties();

		~Node();

	protected:
		std::string name;
		uint32_t endOffset;
		uint32_t numProperties;

		std::vector<std::variant<uint8_t, int16_t, int32_t, int64_t, float, double, propertyArray_t>> properties;

		std::vector<Node*> nodes;
	};
}