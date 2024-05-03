#pragma once
#include "../../cfg.h"
#include "stack"

namespace util {

	using propertyArray_t = std::vector<std::variant<int8_t, int32_t, int64_t, float, double>>;

	class Node {
	public:
		Node(std::string name, uint32_t endOffset, uint32_t numProperties) {
			this->name = name;
			this->endOffset = endOffset;
			this->numProperties = numProperties;
		}

		void addProperties(std::vector<std::variant<uint8_t, int16_t, int32_t, int64_t, float, double, propertyArray_t>> properties) {
			this->properties = properties;
		}

		void addNode(Node* node) {
			nodes.push_back(node);
		}

		uint32_t getEndOffset() {
			return endOffset;
		}

		std::string getName() {
			return name;
		}

		std::vector<Node*> getChildNodes() {
			return nodes;
		}

		std::vector<std::variant<uint8_t, int16_t, int32_t, int64_t, float, double, propertyArray_t>> getProperties() {
			return properties;
		}

		~Node() {
			for (Node* n : nodes) {
				delete n;
			}
		}

	protected:
		std::string name;
		uint32_t endOffset;
		uint32_t numProperties;

		std::vector<std::variant<uint8_t, int16_t, int32_t, int64_t, float, double, propertyArray_t>> properties;

		std::vector<Node*> nodes;
	};

	class Tree {
	public:
		Tree(uint32_t fileLength) {
			root = new Node("root", fileLength, 0);
			branch.push(root);
		}

		void addToStack(Node* node) {
			branch.push(node);
		}

		void popFromStack() {
			branch.pop();
		}

		Node* topOfStack() {
			return branch.top();
		}

		Node* getRoot() {
			return root;
		}

		~Tree() {
			delete root;
		}

	private:
		Node* root;
		std::stack<Node*> branch;
	};
}