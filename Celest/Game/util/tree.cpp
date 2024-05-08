#include "tree.h"

util::Tree::Tree(uint32_t fileLength) {
	root = new Node("root", fileLength, 0);
	branch.push(root);
}

void util::Tree::addToStack(Node* node) {
	branch.push(node);
}

void util::Tree::popFromStack() {
	branch.pop();
}

util::Node* util::Tree::topOfStack() {
	return branch.top();
}

util::Node* util::Tree::getRoot() {
	return root;
}

util::Tree::~Tree() {
	delete root;
}