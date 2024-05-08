#include "node.h"

util::Node::Node(std::string name, uint32_t endOffset, uint32_t numProperties) {
	this->name = name;
	this->endOffset = endOffset;
	this->numProperties = numProperties;
}

void util::Node::addProperties(std::vector<std::variant<uint8_t, int16_t, int32_t, int64_t, float, double, propertyArray_t>> properties) {
	this->properties = properties;
}

void util::Node::addNode(Node* node) {
	nodes.push_back(node);
}

uint32_t util::Node::getEndOffset() {
	return endOffset;
}

std::string util::Node::getName() {
	return name;
}

std::vector<util::Node*> util::Node::getChildNodes() {
	return nodes;
}

std::vector<std::variant<uint8_t, int16_t, int32_t, int64_t, float, double, util::propertyArray_t>> util::Node::getProperties() {
	return properties;
}

util::Node::~Node() {
	for (Node* n : nodes) {
		delete n;
	}
}