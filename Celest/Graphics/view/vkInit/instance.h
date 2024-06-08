#pragma once
#include "../../../cfg.h"

//namespace for creation functions/definitions etc.
namespace vkInit {

	/**
	* Create a Vulkan instance.
	*
	* @param applicationName The name of the application.
	* 
	* @return A pointer to the created instance.
	* 
	* @throws std::exception Instance couldn't be created.
	*/
	vk::Instance makeInstance(std::string applicationName);

	/**
	* Check whether the requested extensions and layers are supported.
	*
	* @param extensions A list of extension names being requested.
	* @param layers		A list of layer names being requested.
	*
	* @throws std::exception Exprension or layer isn't supported.
	*/
	void checkSupport(std::vector<const char*>& extensions, std::vector<const char*>& layers);

}