#pragma once
#include "../../cfg.h"
#include "node.h"
#include <stack>

namespace util {
	class Tree {
	public:
		Tree(uint32_t fileLength);

		void addToStack(Node* node);

		void popFromStack();

		Node* topOfStack();

		Node* getRoot();

		~Tree();

	private:
		Node* root;
		std::stack<Node*> branch;
	};
}